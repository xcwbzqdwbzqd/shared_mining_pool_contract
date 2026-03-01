// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {SharedMiningPoolV2Base} from "./SharedMiningPoolV2Base.t.sol";

/// @notice This unit test suite verifies zero-gross-reward claims revert and do not lock claimed flags.
contract ClaimZeroGrossRewardDefenseV2Test is SharedMiningPoolV2Base {
    /// @notice This setup activates shares for epoch-2 and advances to epoch-3 so epoch-2 is claimable.
    function setUp() public override {
        super.setUp();

        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();

        _rollToEpoch(3);
    }

    /// @notice This test verifies regular claims with zero inflow revert and do not mark pool or mining epochs as claimed.
    function testClaimRewards_RevertsOnZeroGrossReward_AndDoesNotLockEpoch() external {
        uint64 epoch = 2;

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = epoch;

        assertFalse(pool.epochRegularClaimed(epoch));
        assertFalse(mining.epochClaimed(epoch));

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.ZeroGrossReward.selector, epoch));
        pool.claimRewards(epochs);

        // The revert must roll back both pool-side and mining-side state.
        assertFalse(pool.epochRegularClaimed(epoch));
        assertFalse(mining.epochClaimed(epoch));

        mining.fundEpochReward(epoch, 1_000e18);
        pool.claimRewards(epochs);

        assertTrue(pool.epochRegularClaimed(epoch));
        assertTrue(mining.epochClaimed(epoch));
    }

    /// @notice This test verifies bonus claims with zero inflow revert and do not mark pool or bonus epochs as claimed.
    function testClaimBonusRewards_RevertsOnZeroGrossReward_AndDoesNotLockEpoch() external {
        uint64 epoch = 2;

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = epoch;

        bonus.setBonusEpoch(epoch, true);
        bonus.setBonusClaimsOpen(epoch, true);

        assertFalse(pool.epochBonusClaimed(epoch));
        assertFalse(bonus.bonusClaimed(epoch));

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.ZeroGrossReward.selector, epoch));
        pool.claimBonusRewards(epochs);

        // The revert must roll back both pool-side and bonus-side state.
        assertFalse(pool.epochBonusClaimed(epoch));
        assertFalse(bonus.bonusClaimed(epoch));

        bonus.fundBonusReward(epoch, 200e18);
        pool.claimBonusRewards(epochs);

        assertTrue(pool.epochBonusClaimed(epoch));
        assertTrue(bonus.bonusClaimed(epoch));
    }
}

