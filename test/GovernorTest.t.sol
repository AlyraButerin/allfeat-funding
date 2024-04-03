// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Target} from "../src/Target.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";

contract GovernorTest is Test {
    MyGovernor governor;
    Target target;
    TimeLock timeLock;
    GovToken govToken;

    address public USER = makeAddr("USER");
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour, after a vote is passed
    uint256 public constant VOTING_DELAY = 1; // 1 block, blocks till a proposal is active
    uint256 public constant VOTING_PERIOD = 50400; // 1 week

    address[] public proposers;
    address[] public executors;

    uint256[] public values;
    bytes[] public calldatas;
    address[] public targets;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER); // to allow ourselves to vote
        timeLock = new TimeLock(MIN_DELAY, proposers, executors, USER); // everyone can propose and execute
        governor = new MyGovernor(govToken, timeLock);

        // roles
        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        timeLock.grantRole(executorRole, address(0)); // anyone can execute
        timeLock.revokeRole(adminRole, USER); // remove the default admin role => no more admin
        vm.stopPrank();

        target = new Target(address(this));
        target.transferOwnership(address(timeLock)); // timeLock owns the DAO and DAO owns the timeLock
            // timeLock ultimately controls the box
    }

    function testCantUpdateTargetWithoutGovernance() public {
        vm.expectRevert();
        target.store(1);
    }

    // Big test to check the whole governance process
    function test_GovernanceUpdateTarget() public {
        uint256 valueToStore = 888;
        string memory description = "store 888 in the target";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0); // no value to send
        calldatas.push(encodedFunctionCall);
        targets.push(address(target));

        // 1. propose
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        // Proposal state : 0/Pending, 1/Active, 2/Cancelled, 3/Defeated, 4/Succeeded, 5/Queued, 6/Expired, 7/Executed
        console.log("GovernorTest / Proposal state :", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);
        console.log("GovernorTest / Proposal state :", uint256(governor.state(proposalId)));

        // 2. vote
        string memory reason = "888 is froggy!";
        // support => VoteType : 0/Against, 1/For, 2/Abstain
        uint8 voteWay = 1; // for

        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);
        console.log("GovernorTest / Proposal state :", uint256(governor.state(proposalId)));

        // 3. queue
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);
        console.log("GovernorTest / Proposal state :", uint256(governor.state(proposalId)));

        // 4. execute
        governor.execute(targets, values, calldatas, descriptionHash);

        assert(target.retrieve() == valueToStore);
        console.log("GovernorTest / target value :", target.retrieve());
    }
}
