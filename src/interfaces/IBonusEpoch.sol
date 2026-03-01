// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @notice This interface defines the minimal BonusEpoch methods required by the pool.
interface IBonusEpoch {
    /// @notice This method claims bonus rewards for caller over provided epochs.
    function claimBonus(uint64[] calldata epochs) external;

    /// @notice This view indicates whether an epoch is a bonus epoch.
    function isBonusEpoch(uint64 epoch) external view returns (bool);

    /// @notice This view indicates whether bonus claims are currently open for an epoch.
    function bonusClaimsOpen(uint64 epoch) external view returns (bool);

    /// @notice This view returns BOTCOIN token address used by bonus contract.
    function botcoinToken() external view returns (address);
}
