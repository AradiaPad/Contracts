// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title AradiaRandomDrop
 * @dev ERC721 contract with deterministic random design assignment
 * @notice Uses OpenZeppelin's ERC721, Ownable, and Counters for security and gas efficiency
 */
contract AradiaRandomDrop is ERC721, Ownable {
    using Counters for Counters.Counter;

    // --- State Variables ---
    uint256 public maxSupply = 333;
    uint256 public maxPerWallet = 2;
    string private _baseTokenUri;
    string private _description; 
    Counters.Counter private _tokenIdCounter;
    bool private _paused;

    // Cache design assignments to avoid recomputing (gas optimization)
    mapping(uint256 => uint8) private _tokenDesigns;

    // --- Whitelist Variables ---
    mapping(address => bool) private _whitelisted;
    uint256 public constant WHITELIST_LIMIT = 10;

    // Predefined whitelisted wallets
    address public constant WHITELIST_WALLET_1 = 0xe;
    address public constant WHITELIST_WALLET_2 = 0x6;
    address public constant WHITELIST_WALLET_3 = 0x9;

    // Emitted when a token is minted with its assigned design
    event RandomDesignAssigned(uint256 indexed tokenId, uint8 designId);
    event Whitelisted(address indexed wallet);
    event RemovedFromWhitelist(address indexed wallet);

    // --- Constructor ---
    constructor(
        string memory name,
        string memory symbol,
        string memory tokenUri,
        string memory description 
    ) ERC721(name, symbol) Ownable(msg.sender) {
        _baseTokenUri = tokenUri;
        _description = description; 
        _whitelisted[WHITELIST_WALLET_1] = true;
        _whitelisted[WHITELIST_WALLET_2] = true;
        _whitelisted[WHITELIST_WALLET_3] = true;
    }

    // --- Whitelist Functions ---
    /** @dev Add wallet to whitelist (10 mint allowance) */
    function addToWhitelist(address wallet) external onlyOwner {
        _whitelisted[wallet] = true;
        emit Whitelisted(wallet);
    }

    /** @dev Remove wallet from whitelist */
    function removeFromWhitelist(address wallet) external onlyOwner {
        delete _whitelisted[wallet];
        emit RemovedFromWhitelist(wallet);
    }

    /** @dev Check if wallet is whitelisted */
    function isWhitelisted(address wallet) external view returns (bool) {
        return _whitelisted[wallet];
    }

    // --- Owner Functions ---
    /** @dev Only owner can update the base URI for metadata */
    function setBaseTokenUri(string memory newUri) external onlyOwner {
        _baseTokenUri = newUri;
    }

    /** @dev Set mint limit per wallet (must be > 0) */
    function setMaxPerWallet(uint256 newMax) external onlyOwner {
        require(newMax > 0, "Max per wallet must be > 0");
        maxPerWallet = newMax;
    }

    /** @dev Pause/unpause contract minting */
    function pause(bool shouldPause) external onlyOwner {
        _paused = shouldPause;
    }

    /**
     * @dev Only owner can update the contract description
     * @param newDescription The new description for the contract
     */
    function setDescription(string memory newDescription) external onlyOwner {
        _description = newDescription;
    }

    // --- Core Logic ---
    /** @dev Public mint function with supply and wallet limits */
    function mint() external {
        require(!_paused, "Minting paused");
        require(_tokenIdCounter.current() < maxSupply, "Supply exhausted");

        // Check whitelist for 10 mint allowance
        uint256 userLimit = _whitelisted[msg.sender] ? WHITELIST_LIMIT : maxPerWallet;
        require(balanceOf(msg.sender) < userLimit, "Max per wallet reached");

        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(msg.sender, tokenId);

        uint8 designId = _getRandomDesign(tokenId);
        _tokenDesigns[tokenId] = designId;
        emit RandomDesignAssigned(tokenId, designId);

        _tokenIdCounter.increment();
    }

    /**
     * @dev Deterministic design assignment using tokenId as seed
     * @return 0 or 1 based on tokenId hash (pure function)
     */
    function _getRandomDesign(uint256 tokenId) internal pure returns (uint8) {
        return uint8(uint256(keccak256(abi.encode(tokenId))) % 2);
    }

    /** @dev Get cached design for existing token */
    function getTokenDesign(uint256 tokenId) external view returns (uint8) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenDesigns[tokenId];
    }

    /**
     * @dev Build token URI with design-specific metadata
     * @notice Uses Strings.toString for safe concatenation
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        uint8 designId = _tokenDesigns[tokenId];

        return designId == 0
            ? string(abi.encodePacked(_baseTokenUri, "design1/metadata.json"))
            : string(abi.encodePacked(_baseTokenUri, "design2/metadata.json"));
    }

    // --- Design URI Functions ---
    /**
     * @notice Returns the complete URI for a specific design (0 or 1)
     * @dev Uses the same base URI as tokenURI but allows querying before minting
     * @param designId The design ID (0 or 1)
     * @return The full URI for the design metadata
     */
    function getDesignUri(uint8 designId) external view returns (string memory) {
        require(designId < 2, "Invalid design ID");
        return designId == 0
            ? string(abi.encodePacked(_baseTokenUri, "design1/metadata.json"))
            : string(abi.encodePacked(_baseTokenUri, "design2/metadata.json"));
    }

    /**
     * @notice Returns the contract description
     * @return The description of the contract
     */
    function getDescription() external view returns (string memory) {
        return _description;
    }

    /**
     * @notice Returns URIs for all available designs (0 and 1)
     * @dev Useful for frontend to fetch all possible designs at once
     * @return Array of URIs [design0_uri, design1_uri]
     */
    function getAllDesignUris() external view returns (string[2] memory) {
        return [
            string(abi.encodePacked(_baseTokenUri, "design1/metadata.json")),
            string(abi.encodePacked(_baseTokenUri, "design2/metadata.json"))
        ];
    }

    // --- View Functions ---
    function isPaused() external view returns (bool) { return _paused; }
    function getBaseTokenUri() external view returns (string memory) { return _baseTokenUri; }
    function remainingSupply() public view returns (uint256) { return maxSupply - _tokenIdCounter.current(); }

    /** @dev Verify token existence (checks counter and ownership) */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _tokenIdCounter.current() > tokenId && _ownerOf(tokenId) != address(0);
    }
}