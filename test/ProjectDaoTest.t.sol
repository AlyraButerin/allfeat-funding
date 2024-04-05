// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ProjectDao1} from "../src/ProjectDao1.sol";
import {GovToken} from "../src/GovToken.sol";
import {ArtistVault} from "../src/ArtistVault.sol";
import {DeployDao} from "../script/DeployDao.s.sol";

contract ProjectDaoTest is Test {
    DeployDao daoDeployer;
    ProjectDao1 projectDao;
    GovToken govToken;
    ArtistVault artistVault;

    address public USER = makeAddr("USER");
    //     // test pubk owner
    // address public USER = 0xbfae728Cf6D20DFba443c5A297dC9b344108de90;
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    //     uint256 public constant MIN_DELAY = 3600; // 1 hour, after a vote is passed
    //     uint256 public constant VOTING_DELAY = 1; // 1 block, blocks till a proposal is active
    //     uint256 public constant VOTING_PERIOD = 50400; // 1 week

    address[] public proposers;
    address[] public executors;

    uint256[] public values;
    bytes[] public calldatas;
    address[] public targets;

    function setUp() public {
        daoDeployer = new DeployDao();
        (govToken, projectDao, artistVault) = daoDeployer.run();
        //         // govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        //remove! unused
        govToken.delegate(USER); // to allow ourselves to vote

        //         // timeLock.grantRole(proposerRole, address(governor));
        //         // timeLock.grantRole(executorRole, address(0)); // anyone can execute
        //         // timeLock.revokeRole(adminRole, USER); // remove the default admin role => no more admin
        vm.stopPrank();

        //         // target = new Target(address(this));
        //         // target.transferOwnership(address(timeLock)); // timeLock owns the DAO and DAO owns the timeLock
        //         //     // timeLock ultimately controls the box
        vm.deal(USER, 100 ether);
    }

    //@todo test transfer from Vault not possible without dao

    //Big test to check the whole governance process as time is running out
    function testCompleteWorkflow() public {
        uint256 amountToTransfer = 10 ether;
        string memory description = "transfer 10 to the buy a bass guitar";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("transfertBalance(uint256)", amountToTransfer);
        console.log("encodedFunctionCall (next line):");
        console.logBytes(encodedFunctionCall);

        //Setup Vault context then execute dao process => ownerArtist should receive the funds at the end
        address ownerArtist = artistVault._ownerArtist();
        //Prepare Vault context
        //1. user send funds to the vault via mint function and get the tokens
        vm.startPrank(USER);
        artistVault.mint{value: amountToTransfer}(amountToTransfer);

        console.log("ProjectDaoTest / Vault HMY balance :", address(artistVault).balance);
        console.log("ProjectDaoTest / USER token balance :", artistVault.balances(USER));
        console.log("ProjectDaoTest / USER token balance :", govToken.balanceOf(USER));
        vm.stopPrank();
        //2. user create proposal and vote as he's alone, then execute the proposal

        values.push(0); // no value to send
        calldatas.push(encodedFunctionCall);
        targets.push(address(artistVault));

        // 1. propose
        vm.startPrank(USER);
        uint256 proposalId = projectDao.propose(targets, values, calldatas, description);
        // Proposal state : 0/Pending, 1/Active, 2/Cancelled, 3/Defeated, 4/Succeeded, 5/Queued, 6/Expired, 7/Executed
        console.log("ProjectDaoTest / Proposal state :", uint256(projectDao.state(proposalId)));
        vm.stopPrank();
        //NO VOTING DELAT at the moment
        // vm.warp(block.timestamp + 1);
        // vm.roll(block.number + 1);
        // console.log("ProjectDaoTest / Proposal state :", uint256(projectDao.state(proposalId)));

        // 2. vote
        string memory reason = "Bass is great!";
        // support => VoteType : 0/Against, 1/For, 2/Abstain
        uint8 voteWay = 1; // for

        vm.prank(USER);
        projectDao.castVote(proposalId, voteWay, reason);
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        console.log("ProjectDaoTest / Proposal state :", uint256(projectDao.state(proposalId)));

        // 3. queue // NO QUEUE at the moment
        // bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        // projectDao.queue(targets, values, calldatas, descriptionHash);
        // vm.warp(block.timestamp + 1);
        // vm.roll(block.number + 1);
        // console.log("ProjectDaoTest / Proposal state :", uint256(projectDao.state(proposalId)));

        // close prosposal to change state

        projectDao.closeProposal(proposalId);
        console.log("ProjectDaoTest / Proposal state :", uint256(projectDao.state(proposalId)));

        // 4. execute
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        projectDao.execute(targets, values, calldatas, descriptionHash);

        //5. check the result
        //ownerArtist should receive the funds
        assert(ownerArtist.balance == amountToTransfer);
    }
}
