// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Token
 * @dev A customizable ERC-20 token contract built on OpenZeppelin standards.
 * It features custom decimal settings, initial supply minting to a specified owner,
 * and mint/burn functionality restricted to the token owner.
 */
contract Token is ERC20, Ownable {
    /// @dev Immutable storage for the number of decimals, optimizing gas usage.
    uint8 private immutable _decimals;

    /**
     * @notice Constructs a new custom ERC-20 token and mints the initial supply.
     * @dev Initializes the ERC20 parameters (name, symbol) and sets the initial owner.
     * The initial supply is minted to the provided 'owner' address, adjusted by the 'decimals_'.
     * @param name The name of the token (e.g., "Aradia").
     * @param symbol The symbol of the token (e.g., "ARA").
     * @param initialSupply The base amount of tokens to mint (not yet scaled by decimals).
     * @param decimals_ The number of decimal places for the token (1 to 18).
     * @param owner The address that will receive the initial supply and be the contract owner.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 decimals_,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        require(decimals_ > 0 && decimals_ <= 18, "Decimals out of range (1-18)");
        _decimals = decimals_;

        // Mint the initial supply to the owner, scaled by the custom decimals.
        _mint(owner, initialSupply * (10 ** uint256(decimals_)));
    }

    /**
     * @notice Returns the number of decimals used to get its user representation.
     * @dev Overrides the default OpenZeppelin implementation to use the immutable variable.
     * @return The number of decimals for the token.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Allows the token owner to mint new tokens and assign them to an address.
     * @param to The recipient of the new tokens.
     * @param amount The amount of tokens (including decimals) to mint.
     * @custom:modifier onlyOwner
     */
    function mint(address to, uint256 amount) public onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        _mint(to, amount);
    }

    /**
     * @notice Allows any token holder to burn their own tokens.
     * @param amount The amount of tokens (including decimals) to burn from the sender's balance.
     */
    function burn(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        _burn(_msgSender(), amount);
    }
}