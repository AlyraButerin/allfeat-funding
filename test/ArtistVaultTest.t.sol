// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ArtistVault.sol";
import "../src/GovToken.sol"; // Assurez-vous que le chemin vers GovToken est correct

contract ArtistVaultTest is Test {
    ArtistVault private artistVault;
    GovToken private govToken;
    address private owner;

    function setUp() public {
        owner = address(this); // Dans le contexte de test, `this` est le déploiyant, donc le propriétaire
        govToken = new GovToken(); // Déployer le GovToken
        artistVault = new ArtistVault("baseURI/", address(govToken)); // Déployer ArtistVault avec GovToken
        govToken.transferOwnership(address(artistVault)); // Transférer la propriété de GovToken à ArtistVault, si nécessaire
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

    // Ajoutez d'autres tests au besoin...
}