// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {SharedMiningPoolV2DeployConfig} from "./config/SharedMiningPoolV2DeployConfig.sol";
import {SharedMiningPoolV2} from "../src/SharedMiningPoolV2.sol";

/// @notice Deployment script example for SharedMiningPoolV2.
/// @dev
/// - This script does not read env vars to avoid multi-source configuration.
/// - Use runWithParams(operator, feeRecipient) for real deployment.
contract DeploySharedMiningPoolV2 is Script {
    /// @notice This error indicates required operator or fee recipient is missing.
    error MissingRequiredAddress();

    /// @notice This helper returns locked Base mainnet constructor parameters.
    function buildMainnetParams(address operator_, address feeRecipient_)
        public
        pure
        returns (
            address miningContract,
            address bonusEpoch,
            address operator,
            address feeRecipient,
            uint16 feeBps,
            bytes4 receiptSubmitSelector,
            uint256 maxEpochsPerClaim
        )
    {
        miningContract = SharedMiningPoolV2DeployConfig.MAINNET_MINING;
        bonusEpoch = SharedMiningPoolV2DeployConfig.MAINNET_BONUS;
        operator = operator_;
        feeRecipient = feeRecipient_;
        feeBps = SharedMiningPoolV2DeployConfig.FEE_BPS_BASELINE;
        receiptSubmitSelector = SharedMiningPoolV2DeployConfig.RECEIPT_SUBMIT_SELECTOR_BASELINE;
        maxEpochsPerClaim = SharedMiningPoolV2DeployConfig.MAX_EPOCHS_PER_CLAIM_BASELINE;
    }

    /// @notice This default run intentionally reverts unless caller provides non-zero addresses.
    function run() external returns (SharedMiningPoolV2 pool) {
        return runWithParams(address(0), address(0));
    }

    /// @notice This function deploys with mainnet baseline params and caller-provided addresses.
    function runWithParams(address operator_, address feeRecipient_) public returns (SharedMiningPoolV2 pool) {
        if (operator_ == address(0) || feeRecipient_ == address(0)) {
            revert MissingRequiredAddress();
        }

        (
            address miningContract,
            address bonusEpoch,
            address operator,
            address feeRecipient,
            uint16 feeBps,
            bytes4 receiptSubmitSelector,
            uint256 maxEpochsPerClaim
        ) = buildMainnetParams(operator_, feeRecipient_);

        vm.startBroadcast();
        pool = new SharedMiningPoolV2(
            miningContract, bonusEpoch, operator, feeRecipient, feeBps, receiptSubmitSelector, maxEpochsPerClaim
        );
        vm.stopBroadcast();
    }
}
