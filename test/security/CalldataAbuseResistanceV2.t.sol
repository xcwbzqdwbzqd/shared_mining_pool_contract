// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {SharedMiningPoolV2Base} from "../unit/SharedMiningPoolV2Base.t.sol";

/// @notice This security test verifies selector and operator boundaries are enforced.
contract CalldataAbuseResistanceV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies very short calldata is rejected before forwarding.
    function testRejectShortCalldata() external {
        vm.prank(user1);
        pool.deposit(100e18);
        _rollToEpoch(2);
        pool.stakePrincipal();

        bytes memory shortData = hex"1234";

        vm.startPrank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.SelectorMismatch.selector, bytes4(0), pool.receiptSubmitSelector()
            )
        );
        pool.submitReceiptToMining(shortData);
        vm.stopPrank();
    }
}
