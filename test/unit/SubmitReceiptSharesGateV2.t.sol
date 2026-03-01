// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {MockMiningV2} from "../mocks/MockMiningV2.sol";
import {SharedMiningPoolV2Base} from "./SharedMiningPoolV2Base.t.sol";

/// @notice This unit test verifies receipt submission is rejected when the pool has no active shares in the current epoch.
contract SubmitReceiptSharesGateV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies submitReceiptToMining reverts with `NoSharesForEpoch` when `totalActiveShares == 0`.
    function testSubmitReceiptRevertsWhenNoSharesExist() external {
        bytes memory miningCalldata = abi.encodeWithSelector(MockMiningV2.submitReceipt.selector, bytes("r"));

        uint64 current = mining.currentEpoch();

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.NoSharesForEpoch.selector, current));
        pool.submitReceiptToMining(miningCalldata);
    }
}

