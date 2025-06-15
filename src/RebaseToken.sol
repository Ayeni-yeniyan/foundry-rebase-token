// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Ayeni Samuel
 * @notice This is a cross chain rebase token that incentivises users to deposit into the vault.
 * @notice The interest rate can only decrease. Each user will have their own interest rate which is the global interest rate at that time
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    // Errors
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 oldRate,
        uint256 newRate
    );

    // Variables
    uint256 private constant PRECISION_FACTOR = 1e18;

    bytes32 private constant MINT_AND_BURN_ROLE =
        keccak256("MINT_AND_BURN_ROLE");

    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;

    mapping(address user => uint256 interestRate) private s_userInterestRate;

    mapping(address user => uint256 lastTimestamp)
        private s_userLatesUpdateTimestamp;

    // Events
    event InterestRateSet(uint256 newRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Sets the interest rate in this contract
     * @param _newInterestRate new interest rate set
     * @dev the interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                s_interestRate,
                _newInterestRate
            );
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     *
     * @param _of Address of user
     */
    function principleBalanceOf(address _of) external view returns (uint256) {
        return super.balanceOf(_of);
    }

    /**
     * @notice this contract is to mint the token
     * @param _to address to mint to
     * @param _amount amount to mint
     */
    function mint(
        address _to,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);

        s_userInterestRate[_to] = s_interestRate;

        _mint(_to, _amount);
    }

    function burn(
        address _from,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _burn(_from, _amount);
    }

    /**
     * @notice return balance of user including the interest accumulated
     * @param _user User address
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // Get the current principle balance
        return
            (super.balanceOf(_user) *
                _calculateUserAccumulatedInterestSinceLastUpdate(_user)) /
            PRECISION_FACTOR;
    }

    /**
     *
     * @param _recipient RecipientOf transfer
     * @param _amount Amount to be transfered
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(_recipient);
        _mintAccruedInterest(msg.sender);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice to be filled later
     * @param _sender Sender
     * @param _recipient Recipient
     * @param _amount Amount
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(_recipient);
        _mintAccruedInterest(_sender);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Calculate interest accumulated since the last update
     * @param _user Address of user to be calculated for
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp -
            s_userLatesUpdateTimestamp[_user];
        linearInterest =
            PRECISION_FACTOR +
            (s_userInterestRate[_user] * timeElapsed);
    }

    /**
     * @notice This mints the accrued interest to an address
     * @param _user Address to mint accrued interest to
     */
    function _mintAccruedInterest(address _user) internal {
        // find current balance
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        // calculate their current balance including interest
        s_userLatesUpdateTimestamp[_user] = block.timestamp;

        _mint(_user, balanceIncrease);
    }

    /**
     * @notice Gets the user Interest rate
     * @param _user Address of user being queried
     */
    function getUserInterestRate(
        address _user
    ) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
