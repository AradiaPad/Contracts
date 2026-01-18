// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import the required collection contract template.
import "./ERC721Collection.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ERC721Factory
 * @notice Contract responsible for creating and deploying new ERC721 collection contracts.
 * @dev Collects a fixed fee for each collection deployed, utilizing the Pull Pattern for secure withdrawal.
 * Tracks all the Aradia created collections in a mapping and array for easy access and verification .
 * @author 0xNigromante
 */
contract ERC721Factory is Ownable(msg.sender) {

    uint256 public constant CREATION_FEE = 0.5 ether;
    // Mapping to track creation fees pending withdrawal by the owner.
    mapping(address => uint256) private _pendingWithdrawals;

    // --- Collection Tracking ---
    // Array to store all deployed collection addresses
    address[] public deployedCollections;
    // Mapping to verify if an address is a valid collection created by this factory
    mapping(address => bool) public isCollection;

    // --- Events ---
    event CollectionCreated(address indexed collectionAddress, string name, string symbol, address indexed creator);
    event WithdrawalCompleted(address indexed recipient, uint256 amount);

    // The constructor is empty as Ownable(msg.sender) initializes the owner.
    constructor() {}

    /**
     * @notice Creates a new ERC721 collection contract.
     * @dev Requires an exact CREATION_FEE to be sent with the transaction.
     *      Records the new collection address in the tracking system.
     * @param name The name of the collection (for ERC721 name()).
     * @param symbol The symbol for the collection tokens (for ERC721 symbol()).
     * @param baseURI The base URI for NFT metadata (e.g., "ipfs://hash/").
     * @param imageURI The image URI for the collection's minting page.
     * @param description The collection's marketing description.
     * @param maxSupply The maximum number of tokens that can be minted.
     * @param mintFee The fee required to mint a single token.
     * @param maxMintPerWallet mint limit per wallet.
     * @param mintStartTime Unix timestamp for the start of minting.
     * @return The address of the newly created collection contract.
     */

    function createCollection(
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory imageURI,
        string memory description,
        uint256 maxSupply,
        uint256 mintFee,
        uint256 maxMintPerWallet,
        uint256 mintStartTime
    ) external payable returns (address) {
        // Verify required fee and string length limits (Gas Safety).
        require(msg.value == CREATION_FEE, "Incorrect creation fee");
        require(bytes(name).length > 0 && bytes(name).length <= 32, "Name too long (max 32)");
        require(bytes(symbol).length > 0 && bytes(symbol).length <= 10, "Symbol too long (max 10)");
        require(maxMintPerWallet > 0, "Max mint per wallet must be greater than zero");
        // @dev Added validation: Mint start time must be in the future (or current block time).
        require(mintStartTime >= block.timestamp, "Mint start time must be in the future");

        // Record the creation fee for the owner's pending withdrawal.
        _pendingWithdrawals[owner()] = _pendingWithdrawals[owner()] + msg.value;

        // Deploy the ERC721Collection.
        ERC721Collection newCollection = new ERC721Collection(
            name,
            symbol,
            imageURI,
            baseURI,
            description,
            maxSupply,
            mintFee,
            maxMintPerWallet,
            msg.sender,
            mintStartTime // Pass the start time to the constructor
        );

        // Register the new collection in the tracking system
        deployedCollections.push(address(newCollection));
        isCollection[address(newCollection)] = true;

        emit CollectionCreated(address(newCollection), name, symbol, msg.sender);
        return address(newCollection);
    }

    /**
     * @notice Allows the Factory owner to withdraw accumulated creation fees.
     * @dev Implements the secure Pull Pattern by checking the pending balance.
     */
    function withdrawFactoryFees() external onlyOwner {
        uint256 amount = _pendingWithdrawals[owner()];
        require(amount > 0, "No pending withdrawal");

        // Set the pending balance to zero before sending.
        _pendingWithdrawals[owner()] = 0;

        // Send the Ether.
        (bool sent, ) = payable(owner()).call{value: amount}("");

        if (sent) {
            emit WithdrawalCompleted(owner(), amount);
        } else {
            // Revert changes if transfer fails (restore pending balance)
            _pendingWithdrawals[owner()] = amount;
            revert("Transfer failed");
        }
    }

    /**
     * @notice Returns the array of all deployed collection addresses.
     * @dev Useful for frontends or other contracts to query all collections created by this factory.
     * @return Array of collection addresses.
     */
    function getAllCollections() external view returns (address[] memory) {
        return deployedCollections;
    }

    /**
     * @notice Verifies if a given address is a valid collection created by this factory.
     * @dev Useful for validation before interacting with a collection contract.
     * @param collectionAddress The address to verify.
     * @return True if the address is a valid collection, false otherwise.
     */
    function isValidCollection(address collectionAddress) external view returns (bool) {
        return isCollection[collectionAddress];
    }

    /**
     * @notice Rejects direct ETH transfers that are not part of the 'createCollection' function call.
     * @dev Uses the standard Solidity receive() function syntax.
     */
    receive() external payable {
        revert("Direct ETH transfers not allowed (use createCollection)");
    }

    /**
     * @notice Fallback function for calls with unknown data/function signatures.
     */
    fallback() external payable {
        revert("Function not found or direct ETH transfers not allowed");
    }
}