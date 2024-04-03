// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GovToken.sol";

contract ArtistVault is ERC20, ERC721URIStorage, ReentrancyGuard, Ownable {
    uint256 private _nftCounter;
    string private _baseTokenURI;
    GovToken public govToken; // Reference to the GovToken contract

    // Constructor with baseTokenURI and address of GovToken
    constructor(string memory baseTokenURI, address govTokenAddress) 
        ERC721("ArtistVaultNFT", "AVNFT") {
        _baseTokenURI = baseTokenURI;
        govToken = GovToken(govTokenAddress); // Initialize the GovToken instance
    }

    // Mint function for both GovToken and a unique NFT
    function mint(uint256 amount) external payable nonReentrant {
        require(msg.value == amount, "Amount sent does not match the mint amount");

        // Call the mint function of the GovToken contract
        govToken.mint(msg.sender, amount);

        // Mint a unique NFT for the user
        _mintNFT(msg.sender);
    }

    function _mintNFT(address to) private {
        _nftCounter++;
        uint256 newItemId = _nftCounter;

        _safeMint(to, newItemId);
        _setTokenURI(newItemId, _constructTokenURI(newItemId));
    }

    // Construct a token URI for the NFT
    function _constructTokenURI(uint256 tokenId) private view returns (string memory) {
        return string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId)));
    }

    // Allow the owner to update the baseTokenURI
    function setBaseTokenURI(string calldata baseTokenURI) external onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    // Override required due to multiple inheritance.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC20, ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // Withdraw function with access control
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
