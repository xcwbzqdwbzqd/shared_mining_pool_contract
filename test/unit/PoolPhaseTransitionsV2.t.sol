// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {SharedMiningPoolV2Base} from "./SharedMiningPoolV2Base.t.sol";

/// @notice This test verifies permissionless phase transitions and principal-share exit.
contract PoolPhaseTransitionsV2Test is SharedMiningPoolV2Base {
    /// @notice This setup prepares staked principal so unstake/complete-withdraw/restake path is reachable.
    function setUp() public override {
        super.setUp();

        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();
    }

    /// @notice This test verifies unstake, complete withdraw, and restake are permissionless.
    function testPermissionlessTransitionPath() external {
        vm.prank(user2);
        pool.unstakeAtEpochEnd();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.Cooldown));

        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);

        vm.prank(user2);
        pool.completeWithdraw();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.WithdrawnIdle));

        vm.prank(user2);
        pool.restake();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.ActiveStaked));
    }

    /// @notice This test verifies user can claim principal share only after pool funds are withdrawn from mining.
    function testClaimMyShareInWithdrawnIdle() external {
        pool.unstakeAtEpochEnd();

        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);

        pool.completeWithdraw();

        uint256 before = botcoin.balanceOf(user1);
        vm.prank(user1);
        pool.claimMyShare(40e18, user1);

        assertEq(botcoin.balanceOf(user1), before + 40e18);
        assertEq(pool.userPrincipal(user1), 60e18);
    }

    /// @notice This test verifies principal-share claim is rejected before complete withdraw.
    function testClaimMyShareRejectedBeforeCompleteWithdraw() external {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.InvalidPhase.selector,
                SharedMiningPoolV2.PoolPhase.WithdrawnIdle,
                SharedMiningPoolV2.PoolPhase.ActiveStaked
            )
        );
        pool.claimMyShare(1e18, user1);
        vm.stopPrank();
    }
}
