// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {SharedMiningPoolV2Base} from "./SharedMiningPoolV2Base.t.sol";

/// @notice This test verifies next-epoch activation behavior and deposit gating.
contract DepositActivationNextEpochV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies deposit increases pending shares for next epoch and not current epoch.
    function testDepositActivatesOnlyAtNextEpoch() external {
        vm.prank(user1);
        pool.deposit(100e18);

        assertEq(pool.userSharesAtEpoch(user1, 1), 0);
        assertEq(pool.userSharesAtEpoch(user1, 2), 100e18);
        assertEq(pool.scheduledActivationShares(2), 100e18);

        _rollToEpoch(2);

        assertEq(pool.totalActiveShares(), 100e18);
    }

    /// @notice This test verifies deposit is blocked outside ActiveStaked phase.
    function testDepositBlockedInCooldown() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);

        pool.stakePrincipal();
        pool.unstakeAtEpochEnd();

        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.DepositClosed.selector, SharedMiningPoolV2.PoolPhase.Cooldown)
        );
        pool.deposit(1e18);
        vm.stopPrank();
    }
}
