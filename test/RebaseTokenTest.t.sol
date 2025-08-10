// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Vault} from "../src/Vault.sol";
import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(address(rebaseToken));
        rebaseToken.grantMintAndBurnRole(address(vault));
        // (bool success, ) = address(vault).call{value: 1 ether}("");
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    // function testDepositLinear(uint256 amount) public {
    //     amount = bound(amount, 1e5, 1e18);
    //     vm.startPrank(user);
    //     vm.deal(user, amount);
    //     vault.deposit{value: amount}();
    //     uint256 startingBalance = rebaseToken.balanceOf(user);
    //     assertEq(startingBalance, amount);

    //     vm.warp(block.timestamp + 1 hours);
    //     rebaseToken.transfer(user, 0); // Trigger rebase by transferring tokens
    //     uint256 middleBalance = rebaseToken.balanceOf(user);
    //     assertGt(middleBalance, startingBalance);

    //     vm.warp(block.timestamp + 1 hours);
    //     rebaseToken.transfer(user, 0); // Trigger rebase again
    //     uint256 endingBalance = rebaseToken.balanceOf(user);
    //     assertGt(endingBalance, middleBalance);

    //     vm.assertApproxEqAbs(endingBalance - middleBalance, middleBalance - startingBalance, 10);

    //     vm.stopPrank();
    // }

    function testDepositLinear(uint256 amount) public {
        // Deposit funds
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        // 2. check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("block.timestamp", block.timestamp);
        console.log("startBalance", startBalance);
        assertEq(startBalance, amount);
        // 3. warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        console.log("block.timestamp", block.timestamp);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("middleBalance", middleBalance);
        assertGt(middleBalance, startBalance);
        // 4. warp the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        console.log("block.timestamp", block.timestamp);
        console.log("endBalance", endBalance);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        // Deposit funds
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);

        // Redeem straight away
        vault.redeem(type(uint256).max);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertEq(endBalance, 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testCanRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1e5, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);

        vm.deal(user, depositAmount);
        // deposit
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // warp time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositAmount);

        // redee balanceAfterSomeTime
        vm.prank(user);
        vault.redeem(type(uint256).max);
        uint256 ethBalance = address(user).balance;

        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositAmount);
    }

    function testCanTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");

        uint256 userStartBalance = rebaseToken.balanceOf(user);
        uint256 user2StartBalance = rebaseToken.balanceOf(user2);

        assertEq(userStartBalance, amount);
        assertEq(user2StartBalance, 0);

        // Owner reduces interest rate
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // transfer some tokens
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        uint256 userEndBalance = rebaseToken.balanceOf(user);
        uint256 user2EndBalance = rebaseToken.balanceOf(user2);

        assertEq(userEndBalance, userStartBalance - amountToSend);
        assertEq(user2EndBalance, user2StartBalance + amountToSend);

        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotMintAndBurn(uint256 amount) public {
        vm.prank(user);
        uint256 interestRate = rebaseToken.getInterestRate();
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(user, amount, interestRate);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(user, amount);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e15, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        uint256 principleAmount = rebaseToken.principalBalanceOf(user);
        assertEq(principleAmount, amount);

        vm.warp(block.timestamp + 1 hours);
        uint256 newPrincipleAmount = rebaseToken.principalBalanceOf(user);
        assertEq(newPrincipleAmount, amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate, rebaseToken.getInterestRate(), type(uint96).max);
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }

    function testOnlyOwnerCanGrantMintAndBurnRole() public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.grantMintAndBurnRole(address(vault));
    }
}
