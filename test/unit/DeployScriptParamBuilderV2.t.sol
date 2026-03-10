// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {DeploySharedMiningPoolV2} from "../../script/SharedMiningPoolV2.s.sol";

/// @notice This test verifies deployment script parameter builder behavior.
contract DeployScriptParamBuilderV2Test is Test {
    /// @notice This test verifies default mainnet constants are wired by builder.
    function testBuildMainnetParamsUsesBaselineDefaults() external {
        DeploySharedMiningPoolV2 deployScript = new DeploySharedMiningPoolV2();

        (
            address miningContract,
            address bonusEpoch,
            address operator,
            address feeRecipient,
            uint16 feeBps,
            bytes4 selector,
            uint256 maxEpochsPerClaim
        ) = deployScript.buildMainnetParams(address(0x11), address(0x22));

        assertEq(miningContract, 0xcF5F2D541EEb0fb4cA35F1973DE5f2B02dfC3716);
        assertEq(bonusEpoch, 0xA185fE194A7F603b7287BC0abAeBA1b896a36Ba8);
        assertEq(operator, address(0x11));
        assertEq(feeRecipient, address(0x22));
        assertEq(feeBps, 500);
        assertEq(selector, bytes4(0xf9b5aac1));
        assertEq(maxEpochsPerClaim, 20);
    }

    /// @notice This test verifies explicit zero-address safety check in runWithParams.
    function testRunWithParamsRevertsOnZeroAddress() external {
        DeploySharedMiningPoolV2 deployScript = new DeploySharedMiningPoolV2();

        vm.expectRevert(abi.encodeWithSelector(DeploySharedMiningPoolV2.MissingRequiredAddress.selector));
        deployScript.runWithParams(address(0), address(0x22));
    }
}

