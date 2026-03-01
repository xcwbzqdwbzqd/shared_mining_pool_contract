// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {SharedMiningPoolV2Base} from "./SharedMiningPoolV2Base.t.sol";

/// @notice This test verifies permissionless phase transitions and principal exit.
contract PoolPhaseTransitionsV2Test is SharedMiningPoolV2Base {
    /// @notice This setup prepares staked principal so unstake/finalize/restake path is reachable.
    function setUp() public override {
        super.setUp();

        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();
    }

    /// @notice This test verifies unstake, finalize withdraw, and restake are permissionless.
    function testPermissionlessTransitionPath() external {
        vm.prank(user2);
        pool.unstakeAtEpochEnd();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.Cooldown));

        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);

        vm.prank(user2);
        pool.finalizeWithdraw();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.WithdrawnIdle));

        vm.prank(user2);
        pool.restake();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.ActiveStaked));
    }

    /// @notice This test verifies user can withdraw principal only after pool funds are withdrawn from mining.
    function testPrincipalWithdrawInWithdrawnIdle() external {
        pool.unstakeAtEpochEnd();

        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);

        pool.finalizeWithdraw();

        uint256 before = botcoin.balanceOf(user1);
        vm.prank(user1);
        pool.withdrawPrincipal(40e18, user1);

        assertEq(botcoin.balanceOf(user1), before + 40e18);
        assertEq(pool.userPrincipal(user1), 60e18);
    }

    /// @notice This test verifies principal withdrawal is rejected before WithdrawnIdle phase.
    function testWithdrawPrincipalRejectedBeforeFinalize() external {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.InvalidPhase.selector,
                SharedMiningPoolV2.PoolPhase.WithdrawnIdle,
                SharedMiningPoolV2.PoolPhase.ActiveStaked
            )
        );
        pool.withdrawPrincipal(1e18, user1);
        vm.stopPrank();
    }
}
