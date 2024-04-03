// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/* @note
 * musical project entity (must have an artist, transfer functions...
 * add artist initialisation in constructor
 * def of project
 * ?? collection and/or nft ?? add registry or mint via this plateforme ??
 */
// Base of Box contract
contract Target is Ownable {
    uint256 private number;

    event NumberChanged(uint256 newValue);

    constructor(address owner) Ownable(owner) {
        number = 0;
    }

    function store(uint256 newNumber) public onlyOwner {
        number = newNumber;
        emit NumberChanged(newNumber);
    }

    function retrieve() public view returns (uint256) {
        return number;
    }
}
