// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {SharedMiningPoolV2DeployConfig} from "./config/SharedMiningPoolV2DeployConfig.sol";

/// @notice Read-only interface used for deployment baseline verification.
interface ISharedMiningPoolV2View {
    function mining() external view returns (address);
    function bonusEpoch() external view returns (address);
    function operator() external view returns (address);
    function feeRecipient() external view returns (address);
    function feeBps() external view returns (uint16);
    function maxEpochsPerClaim() external view returns (uint256);
    function receiptSubmitSelector() external view returns (bytes4);
}

/// @notice This script validates immutable baseline parameters on a deployed pool contract.
contract VerifyDeploymentV2 is Script {
    /// @notice This error indicates one immutable baseline value mismatched.
    error BaselineMismatch();

    /// @notice This helper verifies locked immutable baselines expected in production release.
    function assertMainnetBaseline(
        address pool,
        address expectedMining,
        address expectedBonus,
        address expectedOperator,
        address expectedFeeRecipient
    ) public view {
        ISharedMiningPoolV2View target = ISharedMiningPoolV2View(pool);
        if (target.mining() != expectedMining) {
            revert BaselineMismatch();
        }
        if (target.bonusEpoch() != expectedBonus) {
            revert BaselineMismatch();
        }
        if (target.operator() != expectedOperator) {
            revert BaselineMismatch();
        }
        if (target.feeRecipient() != expectedFeeRecipient) {
            revert BaselineMismatch();
        }
        if (target.feeBps() != SharedMiningPoolV2DeployConfig.FEE_BPS_BASELINE) {
            revert BaselineMismatch();
        }
        if (target.maxEpochsPerClaim() != SharedMiningPoolV2DeployConfig.MAX_EPOCHS_PER_CLAIM_BASELINE) {
            revert BaselineMismatch();
        }
        if (target.receiptSubmitSelector() != SharedMiningPoolV2DeployConfig.RECEIPT_SUBMIT_SELECTOR_BASELINE) {
            revert BaselineMismatch();
        }
    }

    /// @notice This entrypoint allows calling this check through forge script with explicit pool and address expectations.
    function run(
        address pool,
        address expectedMining,
        address expectedBonus,
        address expectedOperator,
        address expectedFeeRecipient
    ) external view {
        assertMainnetBaseline(pool, expectedMining, expectedBonus, expectedOperator, expectedFeeRecipient);
    }
}
