// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    // Errors
    error Vault__RedeemFailed();
    // Variable

    IRebaseToken private immutable i_rebaseToken;

    // Events
    event Deposit(address indexed to, uint256 amount);
    event Redeem(address indexed to, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice This deposits into the vault
     */
    function deposit() external payable {
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Redeems amount to caller
     * @param _amount Amount to be redeemed
     */
    function redeem(uint256 _amount) external {
        if (_amount == 0) {
            revert Vault__RedeemFailed();
        }
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // Burn first
        i_rebaseToken.burn(msg.sender, _amount);
        // Transfer amount
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @return rabase token address
     */
    function getRebaseTokenAddress() public view returns (address) {
        return address(i_rebaseToken);
    }
}
