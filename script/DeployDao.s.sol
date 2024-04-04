// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {ProjectDao1} from "../src/ProjectDao1.sol";
// import {MyGovernor} from "../src/MyGovernor.sol";
// import {Target} from "../src/Target.sol";
// import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";

contract DeployDao is Script {
    GovToken public govToken;
    ProjectDao1 public projectDao;
    // TimeLock public timeLock;
    // MyGovernor public governor;
    // Target public target;

    address[] public proposers;
    address[] public executors;
    // test pubk owner
    address owner = 0xbfae728Cf6D20DFba443c5A297dC9b344108de90;

    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour, after a vote is passed
    uint256 public constant VOTING_DELAY = 1; // 1 block, blocks till a proposal is active
    uint256 public constant VOTING_PERIOD = 50400;

    function run() external returns (GovToken, ProjectDao1) {
        vm.startBroadcast(owner);

        govToken = new GovToken();

        // @note : ?? inti_supply = tot_supply = funding target amount ??
        // if Vault is owner => change minter
        govToken.mint(owner, INITIAL_SUPPLY);

        govToken.delegate(owner); // to allow ourselves to vote
        // timeLock = new TimeLock(MIN_DELAY, proposers, executors, owner); // everyone can propose and execute
        projectDao = new ProjectDao1("ACDC", address(govToken));

        // roles
        // bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        // bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        // bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        // timeLock.grantRole(proposerRole, address(governor));
        // timeLock.grantRole(executorRole, address(0)); // anyone can execute
        // timeLock.revokeRole(adminRole, owner); // remove the default admin role => no more admin

        // target = new Target(address(this));
        // target.transferOwnership(address(timeLock)); // timeLock owns the DAO and DAO owns the timeLock
        // timeLock ultimately controls the box
        console.log("Deployed Dao at block", block.number);

        vm.stopBroadcast();
        return (govToken, projectDao);
    }
}
