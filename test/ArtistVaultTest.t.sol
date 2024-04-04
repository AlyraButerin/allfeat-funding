// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ArtistVault.sol";
import "../src/GovToken.sol";

contract ArtistVaultTest is Test {
    ArtistVault public artistVault;
    GovToken public govToken;

    address artist = address(0x1);
    string baseTokenURI = "ipfs://QmYnjbjTKew5zj2MwuGJ4fGfntZPGWanT3qcru2zzTLAGS/";

    // Setup function to deploy the GovToken and ArtistVault contracts before each test
    function setUp() public {
        // Deploy GovToken contract
        govToken = new GovToken();
        
        // Make the test contract the owner of the GovToken to control minting
        // govToken.transferOwnership(address(this));
        
        // Deploy ArtistVault contract with the address of the GovToken contract
        vm.prank(artist); // Simulate the artist's address calling the constructor
        artistVault = new ArtistVault(baseTokenURI, address(govToken));
    }

    // Test the mint function with two users
    function testMint() public {
        // Amount to mint
        uint256 mintAmount = 1 ether;

        // User addresses
        address user2 = address(0x2);

        // Set the balance of the artist and user2 to cover minting costs
        vm.deal(artist, mintAmount);
        vm.deal(user2, mintAmount);

        // Simulate artist minting an NFT
        vm.startPrank(artist);
        artistVault.mint{value: mintAmount}(mintAmount);
        vm.stopPrank();

        // Check if the NFT was minted successfully for the artist
        uint256 artistBalance = artistVault.balanceOf(artist);
        assertEq(artistBalance, 1, "Artist should own 1 NFT after minting");

        // Check if the GovToken balance was updated correctly for the artist
        uint256 artistGovTokenBalance = artistVault.checkGovTokenBalance(artist);
        assertEq(artistGovTokenBalance, mintAmount, "Artist's GovToken balance should match the mint amount");

        // Simulate user2 minting an NFT
        vm.startPrank(user2);
        artistVault.mint{value: mintAmount}(mintAmount);
        vm.stopPrank();

        // Check if the NFT was minted successfully for user2
        uint256 user2Balance = artistVault.balanceOf(user2);
        assertEq(user2Balance, 1, "User2 should own 1 NFT after minting");

        // Check if the GovToken balance was updated correctly for user2
        uint256 user2GovTokenBalance = artistVault.checkGovTokenBalance(user2);
        assertEq(user2GovTokenBalance, mintAmount, "User2's GovToken balance should match the mint amount");
    }

    // Test that a second NFT is not minted for a user who already owns one
    function testNoSecondNFTMinted() public {
        // Amount to mint
        uint256 mintAmount = 1 ether;

        // User address
        address user = address(0x3);

        // Set the balance of the user to cover minting costs, twice
        vm.deal(user, mintAmount * 2);

        // Simulate user minting an NFT the first time
        vm.startPrank(user);
        artistVault.mint{value: mintAmount}(mintAmount);
        vm.stopPrank();

        // Check if the NFT was minted successfully
        uint256 balanceAfterFirstMint = artistVault.balanceOf(user);
        assertEq(balanceAfterFirstMint, 1, "User should own 1 NFT after first minting");

        // Check GovToken balance after first mint
        uint256 govTokenBalanceAfterFirstMint = artistVault.checkGovTokenBalance(user);
        assertEq(govTokenBalanceAfterFirstMint, mintAmount, "User's GovToken balance should match the mint amount after first mint");

        // Attempt to mint a second NFT
        vm.startPrank(user);
        artistVault.mint{value: mintAmount}(mintAmount);
        vm.stopPrank();

        // Check that a second NFT was not minted
        uint256 balanceAfterSecondMint = artistVault.balanceOf(user);
        assertEq(balanceAfterSecondMint, 1, "User should still own only 1 NFT after attempting second minting");

        // Check GovToken balance after second mint
        uint256 govTokenBalanceAfterSecondMint = artistVault.checkGovTokenBalance(user);
        assertEq(govTokenBalanceAfterSecondMint, mintAmount * 2, "User's GovToken balance should be updated correctly after second mint");
    }

}
