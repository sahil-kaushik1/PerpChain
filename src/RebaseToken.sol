// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Sahil Kaushik
 * @notice This is a cross cahin rebase token that incentivizes users to deposit into a vault
 * @notice The Interest ratr can only decrese and never increase
 * @notice Each user will have thier own interest ratethat is the gloabal interest rate
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCannotIncrease(uint256, uint256);

    uint256 private Precision = 1e18; // Precision for the interest rate calculations
    bytes32 private constant Mint_and_Burn_ROLE = keccak256("Mint_and_Burn_ROLE"); // Role for minting and burning tokens
    uint256 private s_interestRate = 5e10; // The global interest rate for the token
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_useLastUpdatedTimestamp; // Last updated timestamp for each use
    // User specific interest rate

    event InterestRateUpdated(uint256 oldInterestRate, uint256 newInterestRate);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    ///////////////////////////
    /////Functions
    ///////////////////////////
    /**
     *
     * @param account  The address of the account to grant the mint and burn role to
     *  @notice This function allows the owner to grant the mint and burn role to an account.
     */
    function grantMintAndBurnRole(address account) external onlyOwner {
        _grantRole(Mint_and_Burn_ROLE, account);
    }

    /**
     *
     * @param _interestRate The new interest rate to set for the token
     * @notice This function allows the owner to set the interest rate for the token.
     * @notice The interest rate can only be decreased, not increased.
     */
    function setInterestRate(uint256 _interestRate) external {
        if (s_interestRate < _interestRate) {
            revert RebaseToken__InterestRateCannotIncrease(s_interestRate, _interestRate);
        }
        emit InterestRateUpdated(s_interestRate, _interestRate);
        // Logic to set the interest rate
        s_interestRate = _interestRate;
    }

    /**
     *
     * @param user address of user
     *  @return The principal balance of the user based on their interest rate
     * @notice This function calculates the principal balance of a user based on their interest rate.
     */
    function principalBalanceOf(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    function mint(address _to, uint256 amount, uint256 _interestRate) external onlyRole(Mint_and_Burn_ROLE) {
        _mintAccruedInterest(_to); // Mint accrued interest before minting new tokens
        s_userInterestRate[_to] = _interestRate; // Set the user's interest rate to the global interest rate
        _mint(_to, amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(Mint_and_Burn_ROLE) {
        _mintAccruedInterest(_from); // Mint accrued interest before minting new tokens

        _burn(_from, _amount);
    }

    /**
     *
     * @param _user address of the user to mint accrued interest for
     * @notice  this funciton gives the balance of _user after calculating the accrued interest
     */
    function balanceOf(address _user) public view override returns (uint256) {
        uint256 currentBalance = super.balanceOf(_user);
        if (currentBalance == 0) {
            return 0;
        }
        return (currentBalance * _calculateAccumulatedInterest(_user)) / Precision;
    }

    function _calculateAccumulatedInterest(address _user) internal view returns (uint256) {
        uint256 timediff = block.timestamp - s_useLastUpdatedTimestamp[_user];
        return (s_userInterestRate[_user] * timediff) + Precision;
    }

    /**
     * @dev transfers tokens from the sender to the recipient. This function also mints any accrued interest since the last time the user's balance was updated.
     * @param _recipient the address of the recipient
     * @param _amount the amount of tokens to transfer
     * @return true if the transfer was successful
     *
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        // accumulates the balance of the user so it is up to date with any interest accumulated.
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (balanceOf(_recipient) == 0) {
            // Update the users interest rate only if they have not yet got one (or they tranferred/burned all their tokens). Otherwise people could force others to have lower interest.
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @dev transfers tokens from the sender to the recipient. This function also mints any accrued interest since the last time the user's balance was updated.
     * @param _sender the address of the sender
     * @param _recipient the address of the recipient
     * @param _amount the amount of tokens to transfer
     * @return true if the transfer was successful
     *
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        // accumulates the balance of the user so it is up to date with any interest accumulated.
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (balanceOf(_recipient) == 0) {
            // Update the users interest rate only if they have not yet got one (or they tranferred/burned all their tokens). Otherwise people could force others to have lower interest.
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function _mintAccruedInterest(address _user) internal {
        uint256 previousBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceincrease = currentBalance - previousBalance;
        _mint(_user, balanceincrease);
        s_useLastUpdatedTimestamp[_user] = block.timestamp; // Update the last updated timestamp for the user
    }

    /**
     *
     * @param user The address of the user to get the interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }
}
