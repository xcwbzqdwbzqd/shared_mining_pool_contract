// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {SharedMiningPoolContract} from "../../src/SharedMiningPoolContract.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockMining} from "../mocks/MockMining.sol";

/// @notice Core Cutoff-mode semantics tests:
/// - deposits in epoch N do not affect tier/credits in epoch N
/// - activation starts only after rollover to epoch N+1
/// - withdraw lock is bound to effective epoch
contract DepositWithdrawCutoffTest is Test {
    address internal operator;
    address internal feeRecipient;
    address internal userActive;
    address internal userPending;

    MockERC20 internal botcoin;
    MockMining internal mining;
    SharedMiningPoolContract internal pool;

    function setUp() external {
        operator = makeAddr("operator");
        feeRecipient = makeAddr("feeRecipient");
        userActive = makeAddr("userActive");
        userPending = makeAddr("userPending");

        botcoin = new MockERC20("Botcoin", "BOT", 18);
        mining = new MockMining(address(botcoin));

        // Set epoch to 0 before deployment so pool.lastCheckpointEpoch matches scenario (avoid time-travel mismatch)
        mining.setEpoch(0);

        pool = new SharedMiningPoolContract({
            miningContract_: address(mining),
            operator_: operator,
            feeRecipient_: feeRecipient,
            feeBps_: 500,
            depositMode_: SharedMiningPoolContract.DepositMode.NextEpochCutoff,
            receiptSubmitSelector_: MockMining.submitReceipt.selector,
            maxEpochsPerClaim_: 20
        });

        botcoin.mint(userActive, 1_000e18);
        botcoin.mint(userPending, 1_000e18);

        vm.prank(userActive);
        botcoin.approve(address(pool), type(uint256).max);
        vm.prank(userPending);
        botcoin.approve(address(pool), type(uint256).max);

        // Configure easy-to-verify tier thresholds: t1=100, t2=200, t3=300
        mining.setTierBalances(100e18, 200e18, 300e18);
    }

    function test_cutoff_pendingDeposit_doesNotAffectCurrentEpochTierOrCredits() external {
        // epoch0: deposit once so it becomes active in epoch1
        vm.prank(userActive);
        pool.deposit(150e18); // effective epoch1

        // epoch1: rollover activation sets pool balance to 150, enough for tier1 but below tier2
        mining.setEpoch(1);
        pool.checkpointEpoch();
        assertEq(botcoin.balanceOf(address(pool)), 150e18);
        assertEq(pool.totalActiveShares(), 150e18);

        // In epoch1, add a large pending deposit (if it polluted tier, credits would jump from 1 to 2)
        vm.prank(userPending);
        pool.deposit(100e18); // pending effective epoch2, funds go into vault

        // Operator submits receipt: tier must use active=150 only, so Δcredits=1
        bytes memory miningCalldata = abi.encodeWithSelector(MockMining.submitReceipt.selector, bytes("receipt"));
        vm.prank(operator);
        pool.submitReceiptToMining(miningCalldata);

        assertEq(pool.epochPoolCredits(1), 1);
    }

    function test_withdraw_locking_usesEffectiveEpoch() external {
        vm.prank(userActive);
        pool.deposit(150e18); // effective epoch1

        mining.setEpoch(1);
        pool.checkpointEpoch();

        // Locked within epoch1: withdrawal is not allowed
        vm.prank(userActive);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolContract.WithdrawLocked.selector, uint64(1), uint64(1)));
        pool.withdraw(1e18, userActive);

        // epoch2: epoch1 ended, withdrawal must be allowed
        mining.setEpoch(2);
        pool.checkpointEpoch();
        vm.prank(userActive);
        pool.withdraw(50e18, userActive);
        assertEq(botcoin.balanceOf(userActive), 1_000e18 - 150e18 + 50e18);
    }
}
