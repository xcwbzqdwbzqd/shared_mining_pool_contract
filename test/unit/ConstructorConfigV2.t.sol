// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {SharedMiningPoolV2Base} from "./SharedMiningPoolV2Base.t.sol";

/// @notice This test verifies constructor immutable and initial state values.
contract ConstructorConfigV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies immutable addresses and fee configuration are stored correctly.
    function testConstructorStoresConfiguration() external view {
        assertEq(address(pool.mining()), address(mining));
        assertEq(address(pool.bonusEpoch()), address(bonus));
        assertEq(pool.operator(), operator);
        assertEq(pool.feeRecipient(), feeRecipient);
        assertEq(pool.feeBps(), 500);
        assertEq(pool.maxEpochsPerClaim(), 50);
    }

    /// @notice This test verifies phase and epoch bootstrap defaults.
    function testConstructorBootstrapsPhaseAndEpoch() external view {
        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.ActiveStaked));
        assertEq(pool.lastSettledEpoch(), mining.currentEpoch());
        assertEq(pool.unstakeAvailableAtEpoch(), mining.currentEpoch() + 1);
    }
}
