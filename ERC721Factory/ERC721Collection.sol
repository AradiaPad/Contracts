// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ERC721Collection
 * @dev Standard ERC721 implementation focused on collection management for Aradia.app
 * @author 0xNigromante
 */
contract ERC721Collection is ERC721, Ownable {
    using Counters for Counters.Counter;

    // --- Collection State Variables ---
    Counters.Counter private _tokenIdCounter;
    
    // Fixed Base URI for NFT metadata.
    string private _fixedBaseURI;
    
    // Collection-level metadata (used for marketing/listing pages, not individual tokens)
    string private _image; 
    string private _description;
    uint256 private _maxSupply;
    uint256 private _mintFee;
    uint256 private _totalMinted;
    address private _creator; 
    uint256 private _maxMintPerWallet;
    
    // @dev Unix timestamp marking when the safeMint function is activated.
    uint256 private _mintStartTime; 

    // Token count minted per address.
    mapping(address => uint256) private _mintCount;

    // Accumulated funds from mint fees
    uint256 public accumulatedFunds; 

    // --- Events ---
    event TokenMinted(address indexed to, uint256 tokenId);
    event FundsWithdrawn(uint256 amount);
    // Event to signal the start of minting.
    event MintingStarted(uint256 startTime);

    // --- Read-Only Data Structure ---
    struct CollectionDetails {
        string name;
        string symbol;
        string image;
        string description;
        string baseURI;
        uint256 maxSupply;
        uint256 mintFee;
        uint256 maxMintPerWallet;
    }

    /**
     * @notice Constructor to initialize collection metadata and parameters, and set the mint start time.
     * @dev If 'mintStartTimeParam' == 0 -> Instant start (block.timestamp).
     * @dev If 'mintStartTimeParam' > 0 -> Scheduled start time.
     */
    constructor(
        string memory name,
        string memory symbol, 
        string memory image,
        string memory baseURI,
        string memory description,
        uint256 maxSupplyParam,
        uint256 mintFeeParam,
        uint256 maxMintPerWalletParam,
        address initialOwner,
        // @param mintStartTimeParam Unix timestamp. Use 0 for instant start.
        uint256 mintStartTimeParam 
    ) ERC721(name, symbol) Ownable(initialOwner) {
        _fixedBaseURI = baseURI; 
        _image = image;
        _description = description;
        _maxSupply = maxSupplyParam;
        _mintFee = mintFeeParam;
        _maxMintPerWallet = maxMintPerWalletParam; 
        _creator = owner();
        _tokenIdCounter.increment(); 
        
        // --- Minting Start Logic ---
        if (mintStartTimeParam == 0) {
            // Option 1: Start immediately
            _mintStartTime = block.timestamp;
        } else {
            // Option 2: Start at the scheduled timestamp
            // Ensures the scheduled time is not set far in the past.
            require(mintStartTimeParam >= block.timestamp, "Scheduled time must be current or future");
            _mintStartTime = mintStartTimeParam;
        }

        emit MintingStarted(_mintStartTime);
    }

    // --- Fallback Functions ---
    // Allows the contract to securely receive ETH (mint fees).
    receive() external payable {}
    fallback() external payable {
        revert("Function not found");
    }
    // --- Public Views ---

    /**
     * @notice Returns comprehensive details about the collection.
     */
    function collectionDetails() external view returns (CollectionDetails memory) {
        return CollectionDetails({
            name: name(),
            symbol: symbol(),
            image: _image,
            description: _description,
            baseURI: _fixedBaseURI,
            maxSupply: _maxSupply,
            mintFee: _mintFee,
            maxMintPerWallet: _maxMintPerWallet
        });
    }
    
    /**
     * @notice Returns the timestamp when minting is scheduled to start.
     */
    function mintStartTime() external view returns (uint256) {
        return _mintStartTime;
    }

    /**
     * @notice Returns the number of tokens minted by a specific wallet.
     */
    function mintCount(address wallet) external view returns (uint256) {
        return _mintCount[wallet];
    }

    /**
     * @notice Public mint function. Requires exact mint fee.
     * @param to The address to receive the newly minted NFT.
     * @return The ID of the newly minted token.
     */
    function safeMint(address to) external payable returns (uint256) {
        // @dev Requires the current block time to be greater than or equal to the scheduled start time.
        require(block.timestamp >= _mintStartTime, "Minting has not started yet"); 
        
        require(msg.value == _mintFee, "Exact mint fee required"); 
        require(_totalMinted < _maxSupply, "Max supply reached");

        // limit per wallet
        require(_mintCount[msg.sender] < _maxMintPerWallet, "Max mint per wallet reached");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _totalMinted = _totalMinted + 1; 
        _mintCount[msg.sender] = _mintCount[msg.sender] + 1; 

        // Accumulate funds before interaction
        accumulatedFunds += msg.value;

        _safeMint(to, tokenId);
        emit TokenMinted(to, tokenId);

        return tokenId;
    }

    // ===========================================
    // ERC-721 METADATA FUNCTIONS
    // ===========================================

    /**
     * @notice Returns the URI for the metadata of a given token ID.
     * @dev Currently returns a fixed URI for all tokens, meaning all share the same metadata file.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // Check if the token exists.
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        
        // Returns the fixed URI (no token ID concatenation).
        return _baseURI();
    }

    /**
     * @dev Internal function to get the base URI string.
     */
    function _baseURI() internal view override returns (string memory) {
        return _fixedBaseURI;
    }
    /**
    * @notice Returns the total number of tokens minted.
    */
    function totalSupply() public view returns (uint256) {
        return _totalMinted;
    }

    // ===============================================
    // FUND MANAGEMENT (PULL PATTERN)
    // ===============================================

    /**
     * @notice Allows the contract owner to securely withdraw accumulated mint fees.
     * @dev Uses the Pull Pattern: updates state (accumulatedFunds=0) before transfer (call).
     */
    function withdrawFunds() external onlyOwner {
        uint256 amount = accumulatedFunds;
        require(amount > 0, "No funds to withdraw");
        
        // Reset balance to zero first (anti-reentrancy measure).
        accumulatedFunds = 0; 
        
        // Transfer the Ether.
        (bool sent, ) = payable(owner()).call{value: amount}("");
        require(sent, "Transfer failed");

        emit FundsWithdrawn(amount);
    }
}