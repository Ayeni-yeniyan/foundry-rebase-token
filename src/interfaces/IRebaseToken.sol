// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRebaseToken {
    function burn(address _to, uint256 _amount) external;

    function mint(
        address _from,
        uint256 _amount,
        uint256 _interestRate
    ) external;

    function balanceOf(address account) external returns (uint256);

    function getUserInterestRate(address _user) external returns (uint256);

    function getInterestRate() external returns (uint256);
}
