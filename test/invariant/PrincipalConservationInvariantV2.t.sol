// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2Base} from "../unit/SharedMiningPoolV2Base.t.sol";

/// @notice This invariant test validates principal liabilities remain covered by staked+pool balances.
contract PrincipalConservationInvariantV2Test is SharedMiningPoolV2Base {
    /// @notice This setup prepares pool with principal and active staking coverage.
    function setUp() public override {
        super.setUp();

        vm.prank(user1);
        pool.deposit(100e18);

        vm.prank(user2);
        pool.deposit(150e18);

        _rollToEpoch(2);
        pool.stakePrincipal();
    }

    /// @notice This invariant-style check ensures principal liabilities are covered by staked plus liquid balances.
    function testInvariant_PrincipalCoverage() external view {
        uint256 staked = mining.stakedAmount(address(pool));
        uint256 liquid = botcoin.balanceOf(address(pool));
        assertGe(staked + liquid, pool.totalPrincipalLiability());
    }
}
