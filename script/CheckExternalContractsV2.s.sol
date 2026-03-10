// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {IBonusEpoch} from "../src/interfaces/IBonusEpoch.sol";
import {IMiningV2} from "../src/interfaces/IMiningV2.sol";

/// @notice This script validates external dependency token consistency before deployment.
contract CheckExternalContractsV2 is Script {
    /// @notice This error indicates MiningV2 token or BonusEpoch mining binding is inconsistent.
    error DependencyMismatch(address miningToken, address bonusMining, address expectedToken, address expectedMining);

    /// @notice This helper asserts MiningV2 exposes the expected token and BonusEpoch binds to the expected MiningV2.
    function assertDependencyConsistency(address mining, address bonus, address expectedToken) public view {
        address miningToken = IMiningV2(mining).botcoinToken();
        address bonusMining = IBonusEpoch(bonus).mining();
        if (miningToken != expectedToken || bonusMining != mining) {
            revert DependencyMismatch(miningToken, bonusMining, expectedToken, mining);
        }
    }

    /// @notice This entrypoint allows calling this check through forge script with explicit arguments.
    function run(address mining, address bonus, address expectedToken) external view {
        assertDependencyConsistency(mining, bonus, expectedToken);
    }
}
