// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @notice Canonical deployment constants for SharedMiningPoolV2 releases.
/// @dev This file is the single source of truth for baseline deployment values.
library SharedMiningPoolV2DeployConfig {
    /// @notice Base mainnet chain id.
    uint256 public constant BASE_MAINNET_CHAIN_ID = 8453;

    /// @notice Base Sepolia chain id.
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;

    /// @notice Base mainnet MiningV2 contract address.
    address public constant MAINNET_MINING = 0xcF5F2D541EEb0fb4cA35F1973DE5f2B02dfC3716;

    /// @notice Base mainnet BonusEpoch contract address.
    address public constant MAINNET_BONUS = 0xA185fE194A7F603b7287BC0abAeBA1b896a36Ba8;

    /// @notice Base mainnet BOTCOIN token address.
    address public constant MAINNET_BOTCOIN = 0xA601877977340862Ca67f816eb079958E5bd0BA3;

    /// @notice Baseline protocol fee in basis points.
    uint16 public constant FEE_BPS_BASELINE = 500;

    /// @notice Baseline maximum epochs per claim batch.
    uint256 public constant MAX_EPOCHS_PER_CLAIM_BASELINE = 20;

    /// @notice Baseline allowlisted selector for receipt forwarding.
    bytes4 public constant RECEIPT_SUBMIT_SELECTOR_BASELINE = bytes4(0xf9b5aac1);
}

