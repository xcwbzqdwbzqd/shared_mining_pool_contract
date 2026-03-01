// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {SharedMiningPoolV2} from "../src/SharedMiningPoolV2.sol";

/// @notice Deployment script example for SharedMiningPoolV2.
/// @dev
/// - This script does not read env vars to avoid multi-source configuration.
/// - This script expects manual parameter fill before execution.
contract DeploySharedMiningPoolV2 is Script {
    function run() external returns (SharedMiningPoolV2 pool) {
        // ===== Fill these values before deployment =====
        address miningContract = address(0);
        address bonusEpoch = address(0);
        address operator = address(0);
        address feeRecipient = address(0);
        uint16 feeBps = 500;
        bytes4 receiptSubmitSelector = bytes4(0);
        uint256 maxEpochsPerClaim = 20;

        vm.startBroadcast();
        pool = new SharedMiningPoolV2(
            miningContract, bonusEpoch, operator, feeRecipient, feeBps, receiptSubmitSelector, maxEpochsPerClaim
        );
        vm.stopBroadcast();
    }
}
