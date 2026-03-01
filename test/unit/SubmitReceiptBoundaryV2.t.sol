// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {MockMiningV2} from "../mocks/MockMiningV2.sol";
import {SharedMiningPoolV2Base} from "./SharedMiningPoolV2Base.t.sol";

/// @notice This test verifies receipt forwarding boundaries.
contract SubmitReceiptBoundaryV2Test is SharedMiningPoolV2Base {
    /// @notice This setup prepares one active epoch with staked principal for submit tests.
    function setUp() public override {
        super.setUp();

        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();
    }

    /// @notice This test verifies only immutable operator can submit receipts.
    function testOnlyOperatorCanSubmit() external {
        bytes memory miningCalldata = abi.encodeWithSelector(MockMiningV2.submitReceipt.selector, bytes("r"));

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.OnlyOperator.selector));
        pool.submitReceiptToMining(miningCalldata);
        vm.stopPrank();
    }

    /// @notice This test verifies selector allowlist enforcement.
    function testSelectorAllowlist() external {
        bytes memory badCalldata = abi.encodeWithSelector(MockMiningV2.claim.selector, new uint64[](0));

        vm.startPrank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.SelectorMismatch.selector,
                MockMiningV2.claim.selector,
                MockMiningV2.submitReceipt.selector
            )
        );
        pool.submitReceiptToMining(badCalldata);
        vm.stopPrank();
    }

    /// @notice This test verifies submit fails if credit delta is zero.
    function testSubmitRequiresPositiveDeltaCredits() external {
        mining.setSubmitCreditDelta(address(pool), 0);

        bytes memory miningCalldata = abi.encodeWithSelector(MockMiningV2.submitReceipt.selector, bytes("r"));

        vm.startPrank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.CreditsDidNotIncrease.selector, uint64(2), uint64(0), uint64(0))
        );
        pool.submitReceiptToMining(miningCalldata);
        vm.stopPrank();
    }
}
