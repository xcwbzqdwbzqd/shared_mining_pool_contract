// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {CheckExternalContractsV2} from "../../script/CheckExternalContractsV2.s.sol";
import {MockBonusEpoch} from "../mocks/MockBonusEpoch.sol";
import {MockMiningV2} from "../mocks/MockMiningV2.sol";

/// @notice This test verifies external dependency sanity checks used in release workflow.
contract ExternalContractSanityV2Test is Test {
    /// @notice This test verifies mismatch between bonus-bound mining and expected mining reverts.
    function testDependencyMismatchReverts() external {
        MockMiningV2 mining = new MockMiningV2(address(0xB0));
        MockBonusEpoch bonus = new MockBonusEpoch(address(0xB1));
        bonus.setMining(address(0xB1));
        CheckExternalContractsV2 checker = new CheckExternalContractsV2();

        vm.expectRevert(
            abi.encodeWithSelector(
                CheckExternalContractsV2.DependencyMismatch.selector,
                address(0xB0),
                address(0xB1),
                address(0xB0),
                address(mining)
            )
        );
        checker.assertDependencyConsistency(address(mining), address(bonus), address(0xB0));
    }

    /// @notice This test verifies matching mining binding and expected token pass without revert.
    function testTokenMatchPasses() external {
        address bot = address(0xB0);
        MockMiningV2 mining = new MockMiningV2(bot);
        MockBonusEpoch bonus = new MockBonusEpoch(bot);
        bonus.setMining(address(mining));
        CheckExternalContractsV2 checker = new CheckExternalContractsV2();

        checker.assertDependencyConsistency(address(mining), address(bonus), bot);
    }
}
