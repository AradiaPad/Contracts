// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Token.sol";

/**
 * @title TokenFactory
 * @dev A factory contract for creating new instances of the custom 'Token' contract.
 * @author [0xNigromante]
 * @custom:version 1.2.0
 */
contract TokenFactory {
    
    // --- Events ---

    /// @dev Emitted when a new token is successfully created.
    event TokenCreated(
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol,
        uint256 initialSupply,
        uint8 decimals
    );

    /// @dev Emitted when the contract owner successfully withdraws commissions.
    event CommissionWithdrawn(
        address indexed owner,
        uint256 amount
    );

    /// @dev Emitted when a refund of excess base currency (ASTR) sent during token creation fails.
    /// @param user The address that sent the transaction and was due a refund.
    /// @param amount The amount of Wei that failed to be refunded.
    event RefundFailed(address indexed user, uint256 amount);

    /// @dev Emitted when a new owner is proposed.
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /// @dev Emitted when ownership is fully transferred to the new owner.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // --- State Variables ---

    /// @dev Array to keep a record of all tokens created by this factory.
    address[] public allTokens;

    /// @dev Mapping to check if an address is a token created by this factory.
    mapping(address => bool) public isTokenFromFactory;

    /// @dev Mapping to store tokens by their creator for fast lookups (O(1)).
    mapping(address => address[]) public creatorToTokens;

    /// @dev The fixed commission amount required to create a token (2 ASTR).
    uint256 public constant COMMISSION_AMOUNT = 2000000000000000000; // 2 ASTR in Wei

    /// @dev The total accumulated commissions in Wei.
    uint256 public totalCommissions;

    /// @dev The address of the contract owner, who can withdraw commissions.
    address public owner;

    /// @dev Address of the pending new owner for the two-step ownership transfer.
    address public pendingOwner;

    /// @dev Tracks failed refunds, allowing users to reclaim them later.
    mapping(address => uint256) public failedRefunds;


    // --- Constructor & Modifiers ---

    /**
     * @dev Sets the deployer of the contract as the initial owner.
     */
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /**
     * @dev Restricts access to functions to only the contract owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    /**
     * @dev Rejects direct unsolicited native token transfers (ASTR) to the contract.
     * Only transfers via `createToken` or successful commission withdrawals are intended.
     */
    receive() external payable {
        revert("ASTR transfer not allowed, use createToken or reclaimRefund");
    }

    // --- Core Factory Function ---

    /**
     * @notice Deploys a new custom Token contract instance.
     * @dev Requires a commission of 'COMMISSION_AMOUNT' (2 ASTR) to be paid with the transaction.
     * Excess payment is refunded, with failed refunds tracked for later recovery.
     * @param name The desired name for the new token.
     * @param symbol The desired symbol for the new token (max 10 characters).
     * @param initialSupply The initial total supply of the token.
     * @param decimals The number of decimal places for the token (1 to 18).
     * @return The address of the newly deployed Token contract.
     */
    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 decimals
    ) external payable returns (address) {
        // Input Validations
        require(bytes(name).length > 0, "Token name cannot be empty");
        require(bytes(symbol).length > 0, "Token symbol cannot be empty");
        require(bytes(symbol).length <= 10, "Token symbol too long");
        require(initialSupply > 0, "Initial supply must be greater than 0");
        require(decimals > 0 && decimals <= 18, "Decimals must be between 1 and 18");
        require(msg.value >= COMMISSION_AMOUNT, "Insufficient commission payment (2 ASTR required)");

        // Commission Handling and Refund
        uint256 refundAmount = msg.value - COMMISSION_AMOUNT;

        if (refundAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
            if (!success) {
                // TRACK FAILED REFUND: Store for later retrieval
                failedRefunds[msg.sender] += refundAmount;
                emit RefundFailed(msg.sender, refundAmount);
            }
        }

        totalCommissions += COMMISSION_AMOUNT;

        // Token Creation
        Token token = new Token(
            name,
            symbol,
            initialSupply,
            decimals,
            msg.sender
        );

        address tokenAddress = address(token);

        // Update storage systems
        allTokens.push(tokenAddress);
        isTokenFromFactory[tokenAddress] = true;
        creatorToTokens[msg.sender].push(tokenAddress);

        emit TokenCreated(
            tokenAddress,
            msg.sender,
            name,
            symbol,
            initialSupply,
            decimals
        );

        return tokenAddress;
    }

    // --- Token Query Functions ---

    /**
     * @notice Retrieves the list of all token addresses created by this factory.
     * @return An array of all deployed token contract addresses.
     */
    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }

    /**
     * @notice Returns the total number of tokens created.
     * @return The count of tokens in the 'allTokens' array.
     */
    function getTokenCount() external view returns (uint256) {
        return allTokens.length;
    }

    /**
     * @notice Retrieves the list of token addresses created by a specific address.
     * @dev This operation is efficient (O(1)) as it uses the 'creatorToTokens' mapping.
     * @param creator The address whose created tokens are requested.
     * @return An array of token addresses created by 'creator'.
     */
    function getTokensByCreator(address creator) external view returns (address[] memory) {
        return creatorToTokens[creator];
    }

    // --- Recovery Functions ---

    /**
     * @notice Allows a user to reclaim native tokens (ASTR) from a previously failed refund.
     * @dev Transfers the accumulated 'failedRefunds[msg.sender]' balance back to the caller.
     */
    function reclaimRefund() external {
        uint256 amount = failedRefunds[msg.sender];
        require(amount > 0, "No failed refund available");

        failedRefunds[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        // If the reclaim fails, the funds are simply re-tracked in the contract's balance
        // and the user can try again later. This is better than losing the funds permanently.
        require(success, "Reclaim failed, try again later");
    }

    // --- Owner Management Functions ---

    /**
     * @notice Returns the current base currency (ASTR/Wei) balance of the factory contract.
     * @dev This balance includes accumulated commissions and funds from failed refunds.
     * @return The contract's balance in Wei.
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Returns the amount of commissions currently available for withdrawal.
     * @custom:modifier onlyOwner
     * @return The 'totalCommissions' amount in Wei.
     */
    function getAvailableCommissions() external view onlyOwner returns (uint256) {
        return totalCommissions;
    }
    
    /**
     * @notice Allows the contract owner to withdraw the accumulated commissions.
     * @dev Sends the entire 'totalCommissions' balance (in ASTR/Wei) to the owner's address.
     * @custom:modifier onlyOwner
     */
    function withdrawCommissions() external onlyOwner {
        require(totalCommissions > 0, "No commissions to withdraw");

        uint256 amount = totalCommissions;
        totalCommissions = 0;

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit CommissionWithdrawn(owner, amount);
    }

    /**
     * @notice Initiates the transfer of ownership to a new address (Step 1 of 2).
     * @dev Sets the 'newOwner' address. The new owner must call 'acceptFactoryOwnership' to complete.
     * Prevents accidental loss of ownership due to misaddressed calls.
     * @param newOwner The address of the intended new contract owner.
     * @custom:modifier onlyOwner
     */
    function transferFactoryOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != owner, "Cannot transfer to current owner");

        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /**
     * @notice Completes the transfer of ownership (Step 2 of 2).
     * @dev Can only be called by the address specified as 'pendingOwner'.
     */
    function acceptFactoryOwnership() external {
        require(msg.sender == pendingOwner, "Caller is not the pending owner");

        address oldOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);

        emit OwnershipTransferred(oldOwner, owner);
    }
}