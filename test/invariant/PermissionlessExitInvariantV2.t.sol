// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {SharedMiningPoolV2Base} from "../unit/SharedMiningPoolV2Base.t.sol";

/// @notice This invariant-style test verifies exit transitions remain callable by non-operator callers.
contract PermissionlessExitInvariantV2Test is SharedMiningPoolV2Base {
    /// @notice This setup prepares a staked state where unstake path is reachable.
    function setUp() public override {
        super.setUp();

        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();
    }

    /// @notice This invariant-style check verifies non-operator caller can progress all exit transitions.
    function testInvariant_NonOperatorCanProgressTransitions() external {
        address arbitraryCaller = makeAddr("arbitrary");

        vm.prank(arbitraryCaller);
        pool.unstakeAtEpochEnd();

        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);

        vm.prank(arbitraryCaller);
        pool.finalizeWithdraw();

        vm.prank(arbitraryCaller);
        pool.restake();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.ActiveStaked));
    }
}
