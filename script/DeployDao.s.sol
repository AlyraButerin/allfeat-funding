// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {ProjectDao1} from "../src/ProjectDao1.sol";
import {GovToken} from "../src/GovToken.sol";
import {ArtistVault} from "../src/ArtistVault.sol";

/**
 * @dev Script to deploy all the project contracts (GovToken, ProjectDao, ArtistVault)
 * @dev AT THE MOMENT : the artist SHOULD BE the deployer
 */
contract DeployDao is Script {
    GovToken public govToken;
    ProjectDao1 public projectDao;
    ArtistVault public artistVault;

    address[] public proposers;
    address[] public executors;
    // test pubk owner
    address owner = 0xbfae728Cf6D20DFba443c5A297dC9b344108de90;

    uint256 public constant INITIAL_SUPPLY = 100 ether;
    string public constant baseTokenURI = "ipfs://bafybeibgdlobniibt4gc6iytoimq7jhg7dbghr3qqp4bpv6q2q2kiyd7om/";
    string public constant projectName = "ACDC";

    function run() external returns (GovToken, ProjectDao1, ArtistVault) {
        vm.startBroadcast(owner);
        //@todo change ownership to artistVAult
        govToken = new GovToken();

        // @note : ?? inti_supply = tot_supply = funding target amount ??
        // if Vault is owner => change minter
        govToken.mint(owner, INITIAL_SUPPLY);

        govToken.delegate(owner); // to allow ourselves to vote
        // timeLock = new TimeLock(MIN_DELAY, proposers, executors, owner); // everyone can propose and execute
        projectDao = new ProjectDao1(projectName, address(govToken));

        artistVault = new ArtistVault(baseTokenURI, address(govToken), address(projectDao), projectName);

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
        return (govToken, projectDao, artistVault);
    }
}
