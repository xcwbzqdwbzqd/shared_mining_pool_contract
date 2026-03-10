// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @notice This mock exposes immutable-like getters used by deployment verifier tests.
contract MockPoolViewV2 {
    /// @notice This state stores mock mining contract address.
    address public mining;

    /// @notice This state stores mock bonus epoch contract address.
    address public bonusEpoch;

    /// @notice This state stores mock operator address.
    address public operator;

    /// @notice This state stores mock fee recipient address.
    address public feeRecipient;

    /// @notice This state stores mock fee basis points.
    uint16 public feeBps;

    /// @notice This state stores mock max epoch batch size.
    uint256 public maxEpochsPerClaim;

    /// @notice This state stores mock selector.
    bytes4 public receiptSubmitSelector;

    /// @notice This constructor sets mock values for verifier testing.
    constructor(
        address mining_,
        address bonusEpoch_,
        address operator_,
        address feeRecipient_,
        uint16 feeBps_,
        uint256 maxEpochsPerClaim_,
        bytes4 receiptSubmitSelector_
    ) {
        mining = mining_;
        bonusEpoch = bonusEpoch_;
        operator = operator_;
        feeRecipient = feeRecipient_;
        feeBps = feeBps_;
        maxEpochsPerClaim = maxEpochsPerClaim_;
        receiptSubmitSelector = receiptSubmitSelector_;
    }
}
