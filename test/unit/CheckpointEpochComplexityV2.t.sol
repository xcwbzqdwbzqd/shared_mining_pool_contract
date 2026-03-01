// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2Base} from "./SharedMiningPoolV2Base.t.sol";

/// @notice This unit test suite validates `_checkpointEpoch()` remains usable under very large epoch jumps.
contract CheckpointEpochComplexityV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies checkpointing a very large epoch jump does not revert in an empty pool.
    function testCheckpointEpoch_LargeJump_NoDeposits_DoesNotRevert() external {
        uint64 farFutureEpoch = 1_000_000;
        mining.setEpoch(farFutureEpoch);

        pool.checkpointEpoch();

        assertEq(pool.lastSettledEpoch(), farFutureEpoch);
        assertEq(pool.totalActiveShares(), 0);
        assertEq(pool.totalSharesAtEpoch(farFutureEpoch), 0);
    }

    /// @notice This test verifies a pending activation at epoch `last + 1` is processed exactly once, even with a large jump.
    function testCheckpointEpoch_LargeJump_WithPendingActivation_ActivatesExactlyOnce() external {
        vm.prank(user1);
        pool.deposit(100e18);

        assertEq(pool.scheduledActivationShares(2), 100e18);
        assertEq(pool.totalActiveShares(), 0);

        uint64 farFutureEpoch = 1_000_000;
        mining.setEpoch(farFutureEpoch);
        pool.checkpointEpoch();

        assertEq(pool.lastSettledEpoch(), farFutureEpoch);
        assertEq(pool.scheduledActivationShares(2), 0);
        assertEq(pool.totalActiveShares(), 100e18);
        assertEq(pool.totalSharesAtEpoch(2), 100e18);
        assertEq(pool.totalSharesAtEpoch(farFutureEpoch), 100e18);
    }

    /// @notice This test verifies multiple same-epoch deposits aggregate into one activation epoch and remain correct under a large jump.
    function testCheckpointEpoch_MultipleDepositsSameEpoch_StillSingleActivationEpoch() external {
        vm.prank(user1);
        pool.deposit(60e18);

        vm.prank(user1);
        pool.deposit(40e18);

        vm.prank(user2);
        pool.deposit(50e18);

        assertEq(pool.scheduledActivationShares(2), 150e18);
        assertEq(pool.userSharesAtEpoch(user1, 2), 100e18);
        assertEq(pool.userSharesAtEpoch(user2, 2), 50e18);

        uint64 farFutureEpoch = 1_000_000;
        mining.setEpoch(farFutureEpoch);
        pool.checkpointEpoch();

        assertEq(pool.scheduledActivationShares(2), 0);
        assertEq(pool.totalActiveShares(), 150e18);
        assertEq(pool.totalSharesAtEpoch(2), 150e18);
        assertEq(pool.totalSharesAtEpoch(farFutureEpoch), 150e18);
    }
}

