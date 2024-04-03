// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * Notes:
 *     -Permit :
 *     Allows for approvals to be made via signatures. We can change account allowances
 *     without needing to send a transaction (and so not requiring holding Ether for gas fees).
 *     -Votes:
 *     Keeps history of account's voting power (which can be delegated).
 *     Token balance not accounting for voting power => needs to delegate to themselves (or another account).
 *     Snapshotting is used to keep track of voting power and avoid use of flashloan to manipulate votes.
 *     -> checkPoint keeps track of the last time the voting power was updated.
 *     -> _afterTokenTransfer updates the voting power of the sender and receiver calling _moveVotingPower
 *     which uses _writeCheckpoint to update the voting power.
 */
contract GovToken is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("GovToken", "GTK") ERC20Permit("GovToken") {}

    /* @note 
     * Vault is owner => only him can mint
     * funds sent to the vault = same amount of tokens minted
     * ?? later : same govToken & vault for all projects (dao, projectContract...)
     * @TODO: add modifier onlyVault & Vault address init via constructor
     * ?? funciton transfer in Vault called by timeLock ??
     */
    // @dev Don't let it be called by anyone ! (like this only to demonstrate tests)
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.

    // function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
    //     super._afterTokenTransfer(from, to, amount);
    // }

    // function _mint(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
    //     super._mint(account, amount);
    // }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
