// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    /*
     * @param minDelay: minimum delay for a proposal to be executed
     * @param proposers: list of addresses that can propose a new operation
     * @param executors: list of addresses that can execute a proposal
     * @param admin: address that can change the proposers, executors and the delay
     */
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        TimelockController(minDelay, proposers, executors, admin)
    {}
}
