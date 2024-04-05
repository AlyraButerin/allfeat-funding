// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {GovToken} from "./GovToken.sol";

///@todo : REORG ORDER OF FUNCTIONS!
/**
 * @title ProjectDao1
 * @notice DAO contract to manage proposals, votes and execution
 * @notice workflow :
 * 1. the artist creates a proposal to retrieve funds for an action (buy a bass, pay a studio, etc.)
 * 2. the funder votes for or against the proposal
 * 3. anyone can call the closeProposal function to end the vote (need to be active and before the end of the attributed period)
 * 4. if the proposal is successful, anyone can execute it
 * 5. at the moment only one action is possible : transfer of funds from the ArtistVault to the artist
 *
 * FOR THE POC the address deploying the contract is the artist, he's owner of all contracts
 * First improvment : renonce ownership of the contracts
 * (at the moment only the DAO can transfer fund from Vault to the artist, so we didn't focus on ownership)
 *
 * FOR THIS POC, things missing to implement later :
 * - quorum and threshold of votes.
 * - staking to lock funds or snapshot mechanism.
 * - queue mechanism to delay execution.
 * - roles and access control.
 * - a special vote to blame the artist and get funds back (if the artist doesn't respect the project anouncement).
 * - reward mechanism to close a proposal and execute it.
 *
 * @dev to save storage details of a proposal are split in 2 structs : ProposalCore and ProposalVote
 * @dev their contents are not stored but the proposal id is the hash of their content
 * @dev you need to compute the hash of the proposal to get its id (calling hashProposal)
 *
 * @dev !!!! FOR THE POC : all time variables are set to : 1 (to be able to test quickly and  interact quickly with the contract)
 */
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
     *              TYPES
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

    ///@dev details of a proposal
    struct ProposalCore {
        address proposer;
        uint256 voteStart;
        uint256 voteEnd;
        ProposalState voteState;
        uint256 etaSeconds;
    }
    ///@dev details of a vote for a proposal

    struct ProposalVote {
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        mapping(address => bool) hasVoted;
    }

    /**
     *
     *              STORAGE
     *
     */
    //@todo => make it constant and add getter
    //@todo add real value!!
    uint256 private s_votingDelay = 1; //.......... time btw proposal and beginning of vote
    uint256 private s_voteDuration = 1;
    uint256 private s_votingPeriod;
    uint256 private s_proposalThreshold = 1; //.....min 1 vote power
    string public s_name;
    GovToken private s_govToken;

    mapping(uint256 proposalId => ProposalCore) private _proposals;
    mapping(uint256 proposalId => ProposalVote) private _proposalVotes;

    //@todo add modifiers and role controls
    /*
     *
     *              CONSTRUCTOR
     *
     */

    //@todo add the version management : EIP712(name_, version())
    constructor(string memory projectName, address govToken) {
        s_name = projectName;
        s_govToken = GovToken(govToken);
    }

    /*
     * @todo remove if not implementing special case to receive funds
     */
    receive() external payable virtual {
        revert GovernorDisabledDeposit();
    }

    //@todo add fallback the same way as receive if needed

    //@todo add supportsInterface

    /**
     * @dev Gets the name of the project
     */
    function name() public view virtual returns (string memory) {
        return s_name;
    }

    /**
     * @dev function to compute the id of a proposal
     * @param targets array of addresses of the contracts to interact with
     * @param values array of values to send to the contracts
     * @param calldatas array of calldatas to send to the contracts
     * @param descriptionHash hash of the description of the proposal
     * @return proposalId the id of the proposal
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
    }

    /**
     * @dev function to get the state of a proposal
     * @param proposalId the id of the proposal
     * @return the state of the proposal
     */
    function state(uint256 proposalId) public view virtual returns (ProposalState) {
        ProposalCore storage proposal = _proposals[proposalId];
        return proposal.voteState;
    }

    /**
     * @dev Gets the proposer of the proposal
     * @param proposalId the id of the proposal
     * @return the address of the proposer
     */
    function proposalProposer(uint256 proposalId) public view virtual returns (address) {
        return _proposals[proposalId].proposer;
    }

    //@todo 2 types of proposal : from artist to get funds / from funder to get funds back OR other stuff
    //@todo add check _isValidDescriptionForProposer to prevent front-running of proposals
    //@todo add snapshot support
    //@todo add CHECK INVESTOR NFT to authorize vote
    /**
     * @dev Function to allow the artist or funders to propose a new action
     * @dev It checks if the proposer has enough votes to propose
     * @dev It checks if the proposal is not already active
     * @param targets array of addresses of the contracts to interact with
     * @param values array of values to send to the contracts
     * @param calldatas array of calldatas to send to the contracts
     * @param description description of the proposal
     * @return proposalId the id of the proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256 proposalId) {
        //@todo modify getVotes to get votes at a specific timepoint
        uint256 proposerVotes = s_govToken.balanceOf(msg.sender);
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

    /**
     * @dev function to check if an account has voted for a proposal
     * @param proposalId the id of the proposal
     * @param account the address of the account to check
     * @return true if the account has voted, false otherwise
     */
    function hasVoted(uint256 proposalId, address account) public view virtual returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /**
     * @dev It allows an account to vote for a proposal
     * @param proposalId the id of the proposal
     * @param voteChoice the choice of the vote (0 : Against, 1 : For, 2 : Abstain)
     * @param reason the reason of the vote
     * @return weight the weight of the vote
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
    //@todo replace by a queuing mechanism

    /*
     * @dev end the vote to pass his state to Succeeded or Defeated or Expired
     * @dev anybody can call this function
     * @dev if the proposal is successful, the state is set to Succeeded
     * @dev if the proposal is not successful, the state is set to Defeated
     * @dev Sould be called AFTER the end of the vote (voteStart + voteDuration)
     * @param proposalId the id of the proposal
     * @return the id of the proposal
     */
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
     * @dev Function to execute a proposal
     * @dev It checks if the proposal is in the state Succeeded
     * @dev It executes the calls to the contracts
     * @param targets array of addresses of the contracts to interact with
     * @param values array of values to send to the contracts
     * @param calldatas array of calldatas to send to the contracts
     * @param descriptionHash hash of the description of the proposal
     * @return the id of the proposal
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        //@todo ADD checks : time is ok,  Id exist (if not state will be Pending)
        if (targets.length != values.length || targets.length != calldatas.length || targets.length == 0) {
            revert GovernorInvalidProposalLength(targets.length, calldatas.length, values.length);
        }

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
}
