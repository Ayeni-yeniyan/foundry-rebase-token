// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

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
        (bool success,) = payable(address(this)).call{value: REWARD_POOL}("");

        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardsToAdd) public {
        (bool success,) = payable(address(vault)).call{value: rewardsToAdd}("");
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

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
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

    function testRedeemAfterSomeTimePassed(uint256 time, uint256 depositAmount) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        // deposit first
        vm.prank(user);
        vm.deal(user, depositAmount);
        vault.deposit{value: depositAmount}();

        vm.warp(block.timestamp + time);
        uint256 balanceAfterTimePassed = rebaseToken.balanceOf(user);
        uint256 rewardIncrease = balanceAfterTimePassed - depositAmount;
        vm.deal(owner, rewardIncrease);
        vm.prank(owner);
        addRewardsToVault(rewardIncrease);

        vm.prank(user);
        vault.redeem(balanceAfterTimePassed);

        uint256 ethBalance = address(user).balance;

        assertEq(ethBalance, balanceAfterTimePassed);
        assertGt(ethBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
        console.log("amount and amount to send bound to", amount, amountToSend);

        // deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        console.log("deposit to vault called");

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        console.log("First assert passed");
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        uint256 postRedeemUserBalance = rebaseToken.balanceOf(user);
        uint256 postRedeemUser2Balance = rebaseToken.balanceOf(user2);
        assertEq(postRedeemUserBalance, userBalance - amountToSend);
        assertEq(postRedeemUser2Balance, amountToSend);

        console.log("final assert passed");

        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function testCannotSetInterestRateIfNotOwner(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotCallBurnAndMint() public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.mint(user, 100);
        vm.expectRevert();
        rebaseToken.burn(user, 100);
    }

    function testGetPrincipalAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate, rebaseToken.getInterestRate() + 1, type(uint256).max);
        vm.prank(owner);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testRevertsWhenAmountZero() public {
        vm.expectRevert();
        vault.redeem(0);
    }
}
