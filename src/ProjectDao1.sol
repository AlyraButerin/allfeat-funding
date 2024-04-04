// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {GovToken} from "./GovToken.sol";

contract ProjectDao1 {
    /**
     *
     *              ERRORS
     *
     */
    error GovernorRestrictedProposer(address proposer);
    error GovernorInsufficientProposerVotes(address proposer, uint256 votes, uint256 threshold);
    error GovernorUnexpectedProposalState(uint256 proposalId, ProposalState state, uint8 expected);
    error GovernorInvalidProposalLength(uint256 targets, uint256 calldatas, uint256 values);
    error GovernorQueueNotImplemented();
    error GovernorExecutionError(address target, bytes returndata);
    error GovernorAlreadyCastVote(address voter);
    error GovernorInvalidVoteType();
    error GovernorDisabledDeposit();
    /**
     *
     *              EVENTS
     *
     */

    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    event ProposalQueued(uint256 indexed id, uint256 eta);
    event ProposalExecuted(uint256 indexed id);
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint8 voteChoice, uint256 votes, string reason);

    /**
     *
     *              STORAGE
     *
     */
    enum ProposalState {
        Pending, //let it to have a default value
        Active,
        Defeated, //Against or not enough votes before end
        Succeeded,
        Executed
    }

    enum VoteType {
        Against,
        For,
        Abstain
    }

    struct ProposalCore {
        address proposer;
        uint256 voteStart;
        uint256 voteEnd;
        ProposalState voteState;
        uint256 etaSeconds;
    }

    struct ProposalVote {
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        mapping(address => bool) hasVoted;
    }

    //@todo => make it constant and add getter
    //@todo add real value!!
    uint256 private s_votingDelay = 1;
    uint256 private s_voteDuration = 1;
    uint256 private s_votingPeriod;
    uint256 private s_proposalThreshold = 1; //min 1 vote power
    string public s_name;
    GovToken private s_govToken;

    mapping(uint256 proposalId => ProposalCore) private _proposals;
    mapping(uint256 proposalId => ProposalVote) private _proposalVotes;

    // modifier onlyGovernance() {
    //     _checkGovernance();
    //     _;
    // }
    /*
     *
     *              CONSTRUCTOR
     *
     */

    //@todo add the version management : EIP712(name_, version())
    constructor(string memory name, address govToken) {
        s_name = name;
        s_govToken = GovToken(govToken);
    }

    /**
     * @dev Function to receive ETH that will be handled by the governor (disabled if executor is a third party contract)
     */
    receive() external payable virtual {
        revert GovernorDisabledDeposit();
    }

    //@todo add fallback the same way as receive

    //@todo add supportsInterface

    /**
     * @dev See {IGovernor-name}.
     */
    function name() public view virtual returns (string memory) {
        return s_name;
    }

    //@todo ass version getter

    //@note ? temporary string => description
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
    }

    function state(uint256 proposalId) public view virtual returns (ProposalState) {
        ProposalCore storage proposal = _proposals[proposalId];
        return proposal.voteState;
    }

    /**
     * @dev See {IGovernor-proposalDeadline}.
     */
    // function proposalDeadline(uint256 proposalId) public view virtual returns (uint256) {
    //     return _proposals[proposalId].voteStart + _proposals[proposalId].voteDuration;
    // }

    /**
     * @dev See {IGovernor-proposalProposer}.
     */
    function proposalProposer(uint256 proposalId) public view virtual returns (address) {
        return _proposals[proposalId].proposer;
    }

    //@todo remove for poc
    /**
     * @dev See {IGovernor-proposalNeedsQueuing}.
     */
    // function proposalNeedsQueuing(uint256) public view virtual returns (bool) {
    //     return false;
    // }

    // /**
    //  * @dev Amount of votes already cast passes the threshold limit.
    //  */
    // function _quorumReached(uint256 proposalId) internal view virtual returns (bool);

    // /**
    //  * @dev Is the proposal successful or not.
    //  */
    // function _voteSucceeded(uint256 proposalId) internal view virtual returns (bool);

    //@todo 2 types of proposal : from artist to get funds / from funder to get funds back OR other stuff
    //@todo add check _isValidDescriptionForProposer to prevent front-running of proposals
    //@todo add snapshot support
    //@todo add CHECK INVESTOR NFT to authorize vote
    /**
     * @dev Internal propose mechanism. Can be overridden to add more logic on proposal creation.
     *
     * Emits a {IGovernor-ProposalCreated} event.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256 proposalId) {
        // check proposal threshold
        //@todo modify getVotes to get votes at a specific timepoint
        uint256 proposerVotes = s_govToken.balanceOf(msg.sender); //getVotes(proposer, clock() - 1);
        uint256 votesThreshold = s_proposalThreshold;
        if (proposerVotes < votesThreshold) {
            revert GovernorInsufficientProposerVotes(msg.sender, proposerVotes, votesThreshold);
        }

        proposalId = hashProposal(targets, values, calldatas, keccak256(bytes(description)));

        if (targets.length != values.length || targets.length != calldatas.length || targets.length == 0) {
            revert GovernorInvalidProposalLength(targets.length, calldatas.length, values.length);
        }
        if (_proposals[proposalId].voteStart != 0) {
            revert GovernorUnexpectedProposalState(proposalId, state(proposalId), uint8(0));
        }
        uint256 start = block.timestamp;
        uint256 end = start + s_voteDuration;

        ProposalCore storage proposal = _proposals[proposalId];
        proposal.proposer = msg.sender;
        proposal.voteStart = start;
        proposal.voteEnd = end;
        proposal.voteState = ProposalState.Active;

        emit ProposalCreated(
            proposalId, msg.sender, targets, values, new string[](targets.length), calldatas, start, end, description
        );
    }

    /**
     *
     *  VOTE FUNCTIONS
     *
     */
    //@todo add getter proposalVotes (see GovernorCountingSimple.sol)...

    function hasVoted(uint256 proposalId, address account) public view virtual returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /**
     * @dev See {IGovernor-castVoteWithReason}.
     */
    function castVote(uint256 proposalId, uint8 voteChoice, string calldata reason) public returns (uint256) {
        //@todo ADD CHECK tokens locked OR SNAPSHOT mechanism
        ProposalCore memory proposal = _proposals[proposalId];

        //check if proposal is active
        if (proposal.voteState != ProposalState.Active) {
            revert GovernorUnexpectedProposalState(proposalId, proposal.voteState, uint8(ProposalState.Active));
        }
        //check if time < voteEnd
        if (block.timestamp > _proposals[proposalId].voteEnd) {
            revert GovernorUnexpectedProposalState(proposalId, proposal.voteState, uint8(ProposalState.Active));
        }

        uint256 weight = s_govToken.balanceOf(msg.sender);

        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        if (proposalVote.hasVoted[msg.sender]) {
            revert GovernorAlreadyCastVote(msg.sender);
        }
        proposalVote.hasVoted[msg.sender] = true;

        if (voteChoice == uint8(VoteType.Against)) {
            proposalVote.againstVotes += weight;
        } else if (voteChoice == uint8(VoteType.For)) {
            proposalVote.forVotes += weight;
        } else if (voteChoice == uint8(VoteType.Abstain)) {
            proposalVote.abstainVotes += weight;
        } else {
            revert GovernorInvalidVoteType();
        }

        emit VoteCast(msg.sender, proposalId, voteChoice, weight, reason);

        return weight;
    }

    //@todo MODIFY CONDITIONS => check if vote is successful / for now only For > Against
    //@todo add quorum check !!
    //@todo add queue mechanism and delay before execution
    ///@dev end the vote to pass his state to Succeeded or Defeated or Expired
    ///@dev should be a 'queue' function to be executed after the vote
    function closeProposal(uint256 proposalId) public {
        ProposalCore storage proposal = _proposals[proposalId];

        if (proposal.voteState != ProposalState.Active) {
            revert GovernorUnexpectedProposalState(proposalId, proposal.voteState, uint8(ProposalState.Active));
        }
        if (block.timestamp < proposal.voteEnd) {
            revert GovernorUnexpectedProposalState(proposalId, proposal.voteState, uint8(ProposalState.Active));
        }

        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        if (proposalVote.forVotes > proposalVote.againstVotes) {
            proposal.voteState = ProposalState.Succeeded;
        } else {
            proposal.voteState = ProposalState.Defeated;
        }
    }

    //@todo add a delay before execution
    //@todo think about incentive or reward for execution
    /**
     * @dev everybody can execute a proposal if state is suceeded and the delay has passed
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        //@todo ADD checks : time is ok,  Id exist (if not state will be Pending)
        //@todo check array size equality

        // check if state is Succeeded
        if (_proposals[proposalId].voteState != ProposalState.Succeeded) {
            revert GovernorUnexpectedProposalState(
                proposalId, _proposals[proposalId].voteState, uint8(ProposalState.Succeeded)
            );
        }

        // mark as executed before calls to avoid reentrancy
        _proposals[proposalId].voteState = ProposalState.Executed;

        for (uint256 i = 0; i < targets.length; ++i) {
            (bool success, bytes memory returndata) = targets[i].call{value: values[i]}(calldatas[i]);
            // Address.verifyCallResult(success, returndata);
            if (!success) {
                revert GovernorExecutionError(targets[i], returndata);
            }
        }

        emit ProposalExecuted(proposalId);

        return proposalId;
    }

    //@todo add cancel function to cancel a proposal

    /**
     *
     *  GETTERS
     *
     */

    //@todo implements _isValidDescriptionForProposer to prevent front-running of proposals

    // function votingDelay() public view virtual returns (uint256);

    // function votingPeriod() public view virtual returns (uint256);

    // function quorum(uint256 timepoint) public view virtual returns (uint256);
}
