// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ISBT
 * @notice Interface for Soulbound Token contracts used in crowdfunding campaigns
 */
interface ISBT {
    function mint(address to) external;
}

/**
 * @title CrowdfundProposal
 * @author 0xnigromante
 * @notice Crowdfunding proposal contract that manages contributions and SBT distribution
 * @dev Implements reentrancy protection and follows checks-effects-interactions pattern
 */
contract CrowdfundProposal is ReentrancyGuard {
    /// @notice Address of the campaign creator
    address public creator;

    /// @notice Address of the associated Soulbound Token contract
    address public sbtAddress;

    /// @notice IPFS CID containing campaign metadata
    string public proposalCID;

    /// @notice Funding target amount in wei
    uint256 public targetAmount;

    /// @notice Minimum contribution amount in wei
    uint256 public minContribution;

    /// @notice Campaign end timestamp
    uint256 public endTime;

    /// @notice Flag indicating if refunds are enabled when target isn't met
    bool public refundableEnabled;

    /// @notice Total amount raised in wei
    uint256 public totalRaised;

    /// @notice Mapping of contributor addresses to their contribution amounts
    mapping(address => uint256) public contributions;

    /// @notice Flag indicating if funds have been withdrawn
    bool public fundsWithdrawn;

    /// @notice Emitted when a user contributes to the campaign
    /// @param user Address of the contributor
    /// @param amount Contribution amount in wei
    event Contributed(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims a refund
    /// @param user Address of the user claiming refund
    /// @param amount Refund amount in wei
    event RefundClaimed(address indexed user, uint256 amount);

    /**
     * @notice Contract constructor
     * @dev Initializes campaign parameters and sets the duration
     * @param _creator Address of the campaign creator
     * @param _proposalCID IPFS CID containing campaign metadata
     * @param _target Funding target amount in wei
     * @param _min Minimum contribution amount in wei
     * @param _duration Campaign duration in seconds
     * @param _refundable Flag indicating if refunds are enabled
     */
    constructor(
        address _creator,
        string memory _proposalCID,
        uint256 _target,
        uint256 _min,
        uint256 _duration,
        bool _refundable
    ) {
        creator = _creator;
        proposalCID = _proposalCID;
        targetAmount = _target;
        minContribution = _min;
        endTime = block.timestamp + _duration;
        refundableEnabled = _refundable;
    }

    // Corregido: Solo el creador (o la Factory inicialmente) puede llamar
    // Se añade check de dirección cero
    function setSBT(address _sbt) external {
        require(msg.sender == creator || sbtAddress == address(0), "Unauthorized");
        require(_sbt != address(0), "Invalid SBT address");
        require(sbtAddress == address(0), "SBT already assigned");
        sbtAddress = _sbt;
    }

    /**
     * @notice Allows users to contribute to the campaign
     * @dev Mints an SBT for first-time contributors and updates contribution amounts
     * @dev Protected against reentrancy attacks
     */
    function contribute() external payable nonReentrant {
        require(block.timestamp < endTime, "Crowdfunding completed");
        require(msg.value >= minContribution, "Below the minimum");

        if (contributions[msg.sender] == 0) {
            ISBT(sbtAddress).mint(msg.sender);
        }

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    // Corregido: Patrón Checks-Effects-Interactions + Call (Best Practice 2026)
    /**
     * @notice Allows the creator to withdraw funds if campaign conditions are met
     * @dev Follows checks-effects-interactions pattern and uses low-level call
     * @dev Protected against reentrancy attacks
     */
    function withdraw() external nonReentrant {
        require(msg.sender == creator, "Creator only");
        require(block.timestamp >= endTime, "Still in progress");
        require(totalRaised >= targetAmount || !refundableEnabled, "It does not meet the conditions");
        require(!fundsWithdrawn, "Now retired");

        // EFECTO: Cambiamos el estado antes de la interacción
        fundsWithdrawn = true;

        // INTERACCIÓN: Usamos .call para mayor compatibilidad
        (bool success, ) = payable(creator).call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    /**
     * @notice Allows contributors to claim refunds if campaign fails
     * @dev Only available when refunds are enabled and target wasn't met
     * @dev Follows checks-effects-interactions pattern
     * @dev Protected against reentrancy attacks
     */
    function claimRefund() external nonReentrant {
        require(refundableEnabled, "Refund not enabled");
        require(block.timestamp >= endTime, "Still in progress");
        require(totalRaised < targetAmount, "Goal achieved");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "There are no funds.");

        // EFECTO: Seteamos a cero antes de devolver el dinero
        contributions[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Refund failed");
        emit RefundClaimed(msg.sender, amount);
    }
}