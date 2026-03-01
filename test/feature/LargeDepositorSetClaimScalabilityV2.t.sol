// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2Base} from "../unit/SharedMiningPoolV2Base.t.sol";

/// @notice This feature test exercises many depositors and validates one depositor can still claim efficiently.
contract LargeDepositorSetClaimScalabilityV2Test is SharedMiningPoolV2Base {
    /// @notice This test simulates many depositors contributing principal and validates user claim outcome.
    function testLargeDepositorSetSingleUserClaim() external {
        uint256 depositorCount = 120;
        uint256 depositAmount = 10e18;

        for (uint256 i = 1; i <= depositorCount; i++) {
            address depositor = vm.addr(10_000 + i);
            botcoin.mint(depositor, depositAmount);

            vm.prank(depositor);
            botcoin.approve(address(pool), type(uint256).max);

            vm.prank(depositor);
            pool.deposit(depositAmount);
        }

        _rollToEpoch(2);
        pool.stakePrincipal();

        mining.fundEpochReward(2, 12_000e18);
        _rollToEpoch(3);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        pool.claimRewards(epochs);

        address claimant = vm.addr(10_001);
        uint256 beforeBalance = botcoin.balanceOf(claimant);

        vm.prank(claimant);
        pool.claimUser(epochs, claimant);

        assertGt(botcoin.balanceOf(claimant), beforeBalance);
    }
}
