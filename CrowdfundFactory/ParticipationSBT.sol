// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ParticipationSBT
 * @author 0xnigromante
 * @notice Soulbound Token (SBT) contract for crowdfunding participation
 * @dev Implements non-transferable ERC721 tokens (Soulbound) that represent participation in a crowdfunding campaign
 * @dev Only the associated crowdfunding proposal contract can mint these tokens
 */
contract ParticipationSBT is ERC721, Ownable {
    /// @notice Base URI for token metadata (same for all tokens in this implementation)
    string private _metadataURI;

    /// @notice Counter for assigning token IDs
    uint256 private _currentId;

    /**
     * @notice Contract constructor
     * @dev Initializes the token with name, symbol, and sets the proposal contract as owner
     * @param name Name of the SBT
     * @param symbol Symbol for the SBT
     * @param metadataURI Base URI for token metadata
     * @param proposalContract Address of the associated crowdfunding proposal contract
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory metadataURI,
        address proposalContract
    ) ERC721(name, symbol) Ownable(proposalContract) {
        _metadataURI = metadataURI;
    }

    /**
     * @notice Mints a new Soulbound Token to a contributor
     * @dev Can only be called by the proposal contract (owner)
     * @dev Automatically assigns the next available token ID
     * @param to Address to receive the newly minted token
     */
    // Solo el contrato de la Propuesta puede llamar a esta función
    function mint(address to) external onlyOwner {
        _currentId++;
        _safeMint(to, _currentId);
    }

    /**
     * @notice Overrides transfer functionality to enforce Soulbound property
     * @dev Reverts any attempt to transfer tokens between addresses
     * @dev Allows minting (from address(0)) and burning (to address(0))
     * @param to Destination address
     * @param tokenId ID of the token being transferred
     * @param auth Authorized address (if any)
     * @return address The actual from address (used by parent implementation)
     */
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert("SBT: Transfer prohibited");
        }
        return super._update(to, tokenId, auth);
    }

    /*
     * @notice Returns the metadata URI for a token
     * @dev All tokens share the same metadata URI in this implementation
     * @param tokenId ID of the token (ignored in this implementation)
     * @return string The metadata URI
     */
    function tokenURI(uint256) public view override returns (string memory) {
        return _metadataURI;
    }
}