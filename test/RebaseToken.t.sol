pragma solidity ^0.8.26;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;
    address public owner = makeAddr("OWNER");
    address public user = makeAddr("USER");
    uint256 public SEND_VALUE = 1e5;

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool succcess,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        // 1. Deposit
        amount = bound(amount, 1e6, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        console.log("Balance before deposit:", rebaseToken.balanceOf(user));

        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("Block Timestamp:", block.timestamp);
        console.log("Start Balance:", startBalance);
        assertEq(startBalance, amount, "Deposit mismatch!");

        // 2. Time Warp
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance, "Rebase token did not increase!");

        // 3. Second Time Warp
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance, "Rebase token did not increase after second warp!");

        console.log("End Balance:", endBalance);
        console.log("Balance Diff 1:", middleBalance - startBalance);
        console.log("Balance Diff 2:", endBalance - middleBalance);

        // Adjust tolerance if needed
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 5);

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function addRewardsToVaults(uint256 rewardAmount) public payable {
        console.log(msg.value);
        console.log(rewardAmount);
        // require(msg.value == rewardAmount, "Insufficient ETH sent");

        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
        console.log("Hello");
        require(success, "ETH transfer failed");
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 10000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e6, type(uint96).max);

        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();
        console.log("Deposit:", depositAmount);

        vm.warp(block.timestamp + time);
        uint256 balance = rebaseToken.balanceOf(user);
        console.log("User's rebaseToken balance:", balance);

        // Ensure the vault has enough ETH to cover redemption
        uint256 rewards = balance - depositAmount;
        vm.deal(owner, rewards);
        vm.prank(owner);
        console.log("vault balance", address(vault).balance);
        addRewardsToVaults(rewards);

        console.log("vault balance after", address(vault).balance);

        // Approve if needed (uncomment if redeem uses transferFrom)
        // vm.prank(user);
        // rebaseToken.approve(address(vault), balance);

        console.log("balance of user", rebaseToken.balanceOf(user));
        vm.prank(user);
        vault.redeem(balance);
        console.log("vault balance", address(vault).balance);

        uint256 ethBalance = address(user).balance;
        assertEq(ethBalance, balance, "ETH balance mismatch");
        assertGt(ethBalance, depositAmount, "No profit detected");
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        address user2 = makeAddr("User2");
        amount = bound(amount, 1e6 + 1e6, type(uint96).max);
        amountToSend = bound(amountToSend, 1e6, amount - 1e6);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e8);
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalancAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalancAfterTransfer, user2Balance + amountToSend);
        // After some time has passed, check the balance of the two users has increased
        vm.warp(block.timestamp + 1 days);
        uint256 userBalanceAfterWarp = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterWarp = rebaseToken.balanceOf(user2);
        // check their interest rates are as expected
        // since user two hadn't minted before, their interest rate should be the same as in the contract
        uint256 user2InterestRate = rebaseToken.getUserInterestRate(user2);
        assertEq(user2InterestRate, 5e8);
        // since user had minted before, their interest rate should be the previous interest rate
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        assertEq(userInterestRate, 5e8);

        assertGt(userBalanceAfterWarp, userBalanceAfterTransfer);
        assertGt(user2BalanceAfterWarp, user2BalancAfterTransfer);
    }

    function testSetInterestRate(uint256 interest) public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(interest);
    }

    function testCannotCallMint(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        vm.startPrank(user);
        uint256 interestRate = rebaseToken.getInterestRate();
        vm.expectRevert();
        rebaseToken.mint(user, 1e6, interestRate);
        vm.stopPrank();
    }

    function testCannotCallBurn(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.burn(user, 1e6);
        vm.stopPrank();
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(user), amount);
        vm.warp(block.timestamp + 1 days);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate + 1, type(uint96).max);
        vm.prank(owner);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }
}
