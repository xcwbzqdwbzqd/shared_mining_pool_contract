// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {SharedMiningPoolContract} from "../../src/SharedMiningPoolContract.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockMining} from "../mocks/MockMining.sol";

/// @notice Two-layer settlement test: credits at receipt time -> epoch BOTCOIN claim -> user epoch claim
contract ClaimFlowTest is Test {
    address internal operator;
    address internal feeRecipient;
    address internal user1;
    address internal user2;

    MockERC20 internal botcoin;
    MockMining internal mining;
    SharedMiningPoolContract internal pool;

    function setUp() external {
        operator = makeAddr("operator");
        feeRecipient = makeAddr("feeRecipient");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        botcoin = new MockERC20("Botcoin", "BOT", 18);
        mining = new MockMining(address(botcoin));
        // Keep both receipts at tier1 (avoid second receipt reaching tier2 and producing Δcredits=2)
        mining.setTierBalances(100e18, 500e18, 1_000e18);
        mining.setEpoch(1);

        pool = new SharedMiningPoolContract({
            miningContract_: address(mining),
            operator_: operator,
            feeRecipient_: feeRecipient,
            feeBps_: 500, // 5%
            depositMode_: SharedMiningPoolContract.DepositMode.Immediate,
            receiptSubmitSelector_: MockMining.submitReceipt.selector,
            maxEpochsPerClaim_: 20
        });

        botcoin.mint(user1, 10_000e18);
        botcoin.mint(user2, 10_000e18);

        vm.prank(user1);
        botcoin.approve(address(pool), type(uint256).max);
        vm.prank(user2);
        botcoin.approve(address(pool), type(uint256).max);
    }

    function test_claimFlow_twoUsers_depositTimingMatters() external {
        // user1 deposits 100 first and reaches tier1
        vm.prank(user1);
        pool.deposit(100e18);

        // receipt #1: only user1 has shares
        bytes memory miningCalldata = abi.encodeWithSelector(MockMining.submitReceipt.selector, bytes("r1"));
        vm.prank(operator);
        pool.submitReceiptToMining(miningCalldata);

        // user2 deposits 100 later
        vm.prank(user2);
        pool.deposit(100e18);

        // receipt #2: both users hold 50% share
        miningCalldata = abi.encodeWithSelector(MockMining.submitReceipt.selector, bytes("r2"));
        vm.prank(operator);
        pool.submitReceiptToMining(miningCalldata);

        assertEq(pool.epochPoolCredits(1), 2);

        // End epoch 1: move to epoch 2 and fund epoch-1 reward on mining
        mining.fundEpochReward(1, 1_000e18);
        mining.setEpoch(2);

        // Permissionless claimRewards (called by user2 in this test)
        vm.prank(user2);
        pool.claimRewards(1);

        // gross=1000, fee=50, net=950
        assertEq(botcoin.balanceOf(feeRecipient), 50e18);
        assertEq(pool.epochBotcoinNet(1), 950e18);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 1;

        // user1 claim should be higher (full credits from receipt #1 + half from receipt #2)
        vm.prank(user1);
        pool.claimUser(epochs, user1);

        // user2 claim only gets half from receipt #2
        vm.prank(user2);
        pool.claimUser(epochs, user2);

        // Assert total payout <= net (dust allowed)
        uint256 paid = pool.epochBotcoinPaid(1);
        assertLe(paid, 950e18);

        // Exact expected values under contract integer division
        // user1 creditsScaled = 1.5 * ACC
        // user2 creditsScaled = 0.5 * ACC
        // payout = userScaled * net / (poolCredits * ACC)
        uint256 expectedUser1 = (950e18 * 15) / 20; // 712.5e18 -> 712e18
        uint256 expectedUser2 = (950e18 * 5) / 20; // 237.5e18 -> 237e18
        assertEq(botcoin.balanceOf(user1), 10_000e18 - 100e18 + expectedUser1);
        assertEq(botcoin.balanceOf(user2), 10_000e18 - 100e18 + expectedUser2);
    }

    function test_claimUser_reverts_ifEpochNotClaimed() external {
        vm.prank(user1);
        pool.deposit(100e18);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 1;
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolContract.EpochNotClaimed.selector, uint64(1)));
        pool.claimUser(epochs, user1);
    }

    function test_claimRewards_reverts_ifEpochNotEnded() external {
        // currentEpoch = 1, so claimRewards(1) is not allowed
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolContract.EpochNotEnded.selector, uint64(1), uint64(1)));
        pool.claimRewards(1);
    }
}
