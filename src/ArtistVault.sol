// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GovToken.sol";
import "./Artists.sol";

contract ArtistVault is ERC721URIStorage, ReentrancyGuard, Ownable, Artists {
    uint256 private _nftCounter;
    string private _baseTokenURI;
    GovToken public govToken; // Reference to the GovToken contract

    // Initialize the artist by calling the Artists contract
    address artistsContractAddress = 0x0000000000000000000000000000000000000803;
    Artists artistsInstance = Artists(artistsContractAddress);

    address public _ownerArtist;

    address public _daoManager;

    // balance des govToken
    mapping(address => uint256) public balances;
    uint256 totalGovTokenBalance = 0; // Initialiser la balance totale à 0

    // Constructor with baseTokenURI and address of GovToken
    // Must be called by the artist, only him can create a project.
    constructor(string memory baseTokenURI, address govTokenAddress, address daoManager) 
        ERC721("ArtistVaultNFT", "AVNFT") Ownable(msg.sender) {

        // Define NFT tokenURI
        _baseTokenURI = baseTokenURI;

        // Get the govToken contract.
        govToken = GovToken(govTokenAddress); // Initialize the GovToken instance

        _ownerArtist = msg.sender;

        _daoManager = daoManager;

    }

    // Mint function for both GovToken and a unique NFT
    function mint(uint256 amount) external payable nonReentrant { 
        require(msg.value == amount, "Amount sent does not match the mint amount");

        // Call the mint function of the GovToken contract
        govToken.mint(msg.sender, amount);

        // Update the user's GovToken balance
        balances[msg.sender] += amount;
        totalGovTokenBalance += amount; // Mettre à jour la balance totale

        // Check if the user already owns an NFT, mint only if they don't
        if (balanceOf(msg.sender) == 0) {
            // Mint a unique NFT for the user
            _mintNFT(msg.sender);
        }
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

    function getBaseTokenURI() external view returns (string memory) {
        return _baseURI();
    }

    // Implementing the get_artist function
    function get_artist(address account) external view returns (Artists.Artist memory) {
        return artistsInstance.get_artist(account);
    }

    function checkGovTokenBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    // Fonction pour retourner la balance totale
    function getTotalGovTokenBalance() external view returns (uint256) {
        return totalGovTokenBalance;
    }

    // Fonction pour transférer la balance
    function transfertBalance(uint256 amount) external {
        require(msg.sender == _daoManager, "only daoManager can do this action");
        require(amount <= address(this).balance, "requested amount cannot be above contract balance.");

        // Transfert du montant à _ownerArtist
        (bool success, ) = _ownerArtist.call{value: amount}("");
        require(success, "transfert failed.");
    }

}
