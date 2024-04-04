
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ArtistVault.sol";
import "../src/GovToken.sol";
import "../src/Artists.sol";

contract ArtistVaultTest is Test {
    ArtistVault private artistVault;
    GovToken private govToken;
    Artists private artists;
    address private artist = address(0x1);

    // Setup function to deploy contracts before each test
    function setUp() public {
        govToken = new GovToken();
        address artistsContractAddress = 0x0000000000000000000000000000000000000803;
        artistVault = new ArtistVault("ipfs://QmYnjbjTKew5zj2MwuGJ4fGfntZPGWanT3qcru2zzTLAGS/", address(govToken));
        // Additional setup if needed, e.g., minting tokens, setting roles
    }

    // Test the deployment and initial setup of the ArtistVault
    function testDeployment() public {
        // Verify the initial state, e.g., baseTokenURI, owner, etc.
        assertEq(artistVault.getBaseTokenURI(), "ipfs://QmYnjbjTKew5zj2MwuGJ4fGfntZPGWanT3qcru2zzTLAGS/");
        // Other assertions as necessary
    }

    function testMint() public {
        // Le montant de HMY (dans ce contexte, ETH) que l'utilisateur "paie" pour mint
        uint256 mintAmount = 1 ether;

        // Préparer l'environnement de test pour envoyer de la valeur avec la transaction
        vm.deal(address(1), mintAmount); // Forge VM trick pour fournir de l'ETH à une adresse de test
        vm.startPrank(address(1)); // Commencer à agir comme l'adresse 1

        // Appeler la fonction mint avec la valeur envoyée
        artistVault.mint{value: mintAmount}(mintAmount);

        // Vérifier si le token a été correctement minté
        uint256 balance = govToken.balanceOf(address(1));
        assertEq(balance, mintAmount, "Mint of GovToken failed");

        // Vérifier si un NFT a été minté pour l'utilisateur
        uint256 nftBalance = artistVault.balanceOf(address(1));
        assertEq(nftBalance, 1, "No NFT mint for User.");

        // Vérifier le tokenURI du NFT minté
        string memory expectedTokenURI = string(abi.encodePacked("baseURI/", "1"));
        assertEq(artistVault.tokenURI(1), expectedTokenURI, "tokenURI of the NFT is not valid.");

        vm.stopPrank();
    }
}
