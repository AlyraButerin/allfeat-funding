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

    /*
     * @dev Minimal script to deploy the project contracts
     * @dev ownership should be managed later (artist renonce ownership ...)
     */
    function run() external returns (GovToken, ProjectDao1, ArtistVault) {
        //@todo check dployer address used !!!!!!!! TO CHANGE !!!!
        vm.startBroadcast(owner);
        //@todo change ownership to artistVAult
        govToken = new GovToken();
        console.log("Deployed GovToken at address", address(govToken));

        govToken.mint(owner, INITIAL_SUPPLY);

        govToken.delegate(owner); // to allow ourselves to vote
        // timeLock = new TimeLock(MIN_DELAY, proposers, executors, owner); // everyone can propose and execute
        projectDao = new ProjectDao1(projectName, address(govToken));
        console.log("Deployed projectDao at address", address(projectDao));

        artistVault = new ArtistVault(baseTokenURI, address(govToken), address(projectDao), projectName);
        console.log("Deployed artistVault at address", address(artistVault));

        console.log("Deployed Dao at block", block.number);

        vm.stopBroadcast();
        return (govToken, projectDao, artistVault);
    }
}
