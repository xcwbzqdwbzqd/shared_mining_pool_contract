// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {SharedMiningPoolContract} from "../src/SharedMiningPoolContract.sol";

/// @notice Deployment script example
/// @dev
/// - This script does not read env vars to avoid multi-source configuration; fill deployment params in-file before running
/// - For Base mainnet mining address details, see docs/plans/2026-02-24-shared-mining-pool-design.md
contract DeploySharedMiningPoolContract is Script {
    function run() external returns (SharedMiningPoolContract pool) {
        // ===== Fill before deployment (placeholders must be replaced) =====
        address miningContract = address(0);
        address operator = address(0);
        address feeRecipient = address(0);
        uint16 feeBps = 500; // 5%
        SharedMiningPoolContract.DepositMode depositMode = SharedMiningPoolContract.DepositMode.NextEpochCutoff;
        bytes4 receiptSubmitSelector = bytes4(0); // Use first 4 bytes from coordinator mining calldata
        uint256 maxEpochsPerClaim = 20;

        vm.startBroadcast();
        pool = new SharedMiningPoolContract(
            miningContract, operator, feeRecipient, feeBps, depositMode, receiptSubmitSelector, maxEpochsPerClaim
        );
        vm.stopBroadcast();
    }
}
