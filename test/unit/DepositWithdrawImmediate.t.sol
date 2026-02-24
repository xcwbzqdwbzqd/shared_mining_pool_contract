// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {SharedMiningPoolContract} from "../../src/SharedMiningPoolContract.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockMining} from "../mocks/MockMining.sol";

contract DepositWithdrawImmediateTest is Test {
    address internal operator;
    address internal feeRecipient;
    address internal user;

    MockERC20 internal botcoin;
    MockMining internal mining;
    SharedMiningPoolContract internal pool;

    function setUp() external {
        operator = makeAddr("operator");
        feeRecipient = makeAddr("feeRecipient");
        user = makeAddr("user");

        botcoin = new MockERC20("Botcoin", "BOT", 18);
        mining = new MockMining(address(botcoin));

        pool = new SharedMiningPoolContract({
            miningContract_: address(mining),
            operator_: operator,
            feeRecipient_: feeRecipient,
            feeBps_: 500,
            depositMode_: SharedMiningPoolContract.DepositMode.Immediate,
            receiptSubmitSelector_: MockMining.submitReceipt.selector,
            maxEpochsPerClaim_: 20
        });

        botcoin.mint(user, 1_000e18);
        vm.prank(user);
        botcoin.approve(address(pool), type(uint256).max);
    }

    function test_deposit_increasesActiveShares_andLocksCurrentEpoch() external {
        mining.setEpoch(1);

        vm.prank(user);
        pool.deposit(200e18);

        assertEq(pool.totalActiveShares(), 200e18);
        assertEq(botcoin.balanceOf(address(pool)), 200e18);

        // Locked inside the same epoch: locked == deposited, unlocked == 0
        (uint256 sharesCur, uint256 lockedCur, uint256 unlockedCur,) = pool.getUserPrincipalState(user);
        assertEq(sharesCur, 200e18);
        assertEq(lockedCur, 200e18);
        assertEq(unlockedCur, 0);
    }

    function test_withdraw_reverts_beforeEpochEnds() external {
        mining.setEpoch(1);

        vm.prank(user);
        pool.deposit(200e18);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolContract.WithdrawLocked.selector, uint64(1), uint64(1)));
        pool.withdraw(1e18, user);
    }

    function test_withdraw_succeeds_afterEpochEnds() external {
        mining.setEpoch(1);

        vm.prank(user);
        pool.deposit(200e18);

        // Epoch ends (advance to next epoch)
        mining.setEpoch(2);

        vm.prank(user);
        pool.withdraw(50e18, user);

        assertEq(botcoin.balanceOf(user), 1_000e18 - 200e18 + 50e18);
        assertEq(botcoin.balanceOf(address(pool)), 150e18);
        assertEq(pool.totalActiveShares(), 150e18);
    }
}
