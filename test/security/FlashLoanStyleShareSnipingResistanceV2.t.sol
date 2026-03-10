// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {SharedMiningPoolV2Base} from "../unit/SharedMiningPoolV2Base.t.sol";

/// @notice This security test proves same-epoch late capital cannot snipe reward-bearing shares for the current epoch.
contract FlashLoanStyleShareSnipingResistanceV2Test is SharedMiningPoolV2Base {
    /// @notice This test simulates a large late deposit and proves it cannot claim the already-running epoch's rewards.
    function testLateDepositCannotClaimCurrentEpochRewards() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();

        vm.prank(user2);
        pool.deposit(50_000_000e18);

        assertEq(pool.userSharesAtEpoch(user2, 2), 0);
        assertEq(pool.totalSharesAtEpoch(2), 100e18);

        mining.fundEpochReward(2, 1_000e18);
        _rollToEpoch(3);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        pool.triggerClaim(epochs);

        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.NothingToClaim.selector));
        pool.claimMyRewards(epochs, user2);
        vm.stopPrank();

        uint256 beforeBalance = botcoin.balanceOf(user1);

        vm.prank(user1);
        pool.claimMyRewards(epochs, user1);

        assertGt(botcoin.balanceOf(user1), beforeBalance);
    }
}
