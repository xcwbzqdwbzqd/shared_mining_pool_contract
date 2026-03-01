// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2Base} from "../unit/SharedMiningPoolV2Base.t.sol";

/// @notice This fuzz test validates reward conservation boundaries for equal-share users.
contract FuzzRewardConservationV2Test is SharedMiningPoolV2Base {
    /// @notice This setup prepares two equal-share users for epoch-2 reward testing.
    function setUp() public override {
        super.setUp();

        vm.prank(user1);
        pool.deposit(100e18);

        vm.prank(user2);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();
        _rollToEpoch(3);
    }

    /// @notice This fuzz case checks total paid rewards never exceed accrued net rewards.
    function testFuzzRewardConservation(uint96 regularAmountRaw, uint96 bonusAmountRaw) external {
        uint256 regularAmount = bound(uint256(regularAmountRaw), 2e18, 1_000_000e18);
        uint256 bonusAmount = bound(uint256(bonusAmountRaw), 0, 1_000_000e18);

        mining.fundEpochReward(2, regularAmount);

        if (bonusAmount != 0) {
            bonus.setBonusEpoch(2, true);
            bonus.setBonusClaimsOpen(2, true);
            bonus.fundBonusReward(2, bonusAmount);
        }

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        pool.claimRewards(epochs);
        if (bonusAmount != 0) {
            pool.claimBonusRewards(epochs);
        }

        vm.prank(user1);
        pool.claimUser(epochs, user1);

        vm.prank(user2);
        pool.claimUser(epochs, user2);

        assertLe(pool.totalRewardsPaid(), pool.totalNetRewardsAccrued());
        assertLe(pool.totalNetRewardsAccrued() - pool.totalRewardsPaid(), 1);
    }
}
