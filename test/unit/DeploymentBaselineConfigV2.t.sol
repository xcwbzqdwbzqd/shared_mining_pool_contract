// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {SharedMiningPoolV2DeployConfig} from "../../script/config/SharedMiningPoolV2DeployConfig.sol";

/// @notice This test verifies baseline deployment constants remain stable.
contract DeploymentBaselineConfigV2Test is Test {
    /// @notice This test verifies locked chain ids, params, and selector constants.
    function testMainnetBaselineConstants() external pure {
        assertEq(SharedMiningPoolV2DeployConfig.BASE_MAINNET_CHAIN_ID, 8453);
        assertEq(SharedMiningPoolV2DeployConfig.BASE_SEPOLIA_CHAIN_ID, 84532);
        assertEq(SharedMiningPoolV2DeployConfig.FEE_BPS_BASELINE, 500);
        assertEq(SharedMiningPoolV2DeployConfig.MAX_EPOCHS_PER_CLAIM_BASELINE, 20);
        assertEq(SharedMiningPoolV2DeployConfig.RECEIPT_SUBMIT_SELECTOR_BASELINE, bytes4(0xf9b5aac1));
    }

    /// @notice This test verifies locked Base mainnet external contract addresses.
    function testMainnetAddressConstants() external pure {
        assertEq(SharedMiningPoolV2DeployConfig.MAINNET_MINING, 0xcF5F2D541EEb0fb4cA35F1973DE5f2B02dfC3716);
        assertEq(SharedMiningPoolV2DeployConfig.MAINNET_BONUS, 0xA185fE194A7F603b7287BC0abAeBA1b896a36Ba8);
        assertEq(SharedMiningPoolV2DeployConfig.MAINNET_BOTCOIN, 0xA601877977340862Ca67f816eb079958E5bd0BA3);
    }
}

