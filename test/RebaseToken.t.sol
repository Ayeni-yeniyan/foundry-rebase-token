// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";

import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;
    uint256 public constant REWARD_POOL = 1e18;
    uint256 public constant DEPOSIT_VALUE = 1e18;
    address public owner = makeAddr("Owner");
    address public user = makeAddr("User");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success, ) = payable(address(this)).call{value: REWARD_POOL}("");

        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // deposit first
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(amount, startBalance);
        // check balance
        rebaseToken.balanceOf(msg.sender);
        // warp time
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(
            endBalance - middleBalance,
            middleBalance - startBalance,
            1
        );
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // deposit first
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(amount, startBalance);
        // Redeem straight away
        vault.redeem(type(uint256).max);
        assertEq(address(vault).balance, 0);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterSomeTimePassed(
        uint256 time,
        uint256 depositAmount
    ) public {
        time = bound(time, 1000, type(uint256).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        // deposit first
        vm.startPrank(user);
        vm.deal(user, depositAmount);
        vm.stopPrank();
        vault.deposit{value: depositAmount}();
        vm.warp(block.timestamp + time);
        uint256 balanceAfterTimePassed = rebaseToken.balanceOf(user);
    }
}
