// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @notice This interface defines the minimal BotcoinMiningV2 methods required by the pool.
interface IMiningV2 {
    /// @notice This view returns the current mining epoch from the mining contract.
    function currentEpoch() external view returns (uint64);

    /// @notice This view returns miner credits for an epoch.
    function credits(uint64 epoch, address miner) external view returns (uint64);

    /// @notice This method claims regular epoch rewards for the caller.
    function claim(uint64[] calldata epochs) external;

    /// @notice This method forwards receipt calldata to mining logic.
    function submitReceipt(bytes calldata miningCalldata) external;

    /// @notice This method stakes BOTCOIN from caller into mining.
    function stake(uint256 amount) external;

    /// @notice This method requests full unstake for caller stake position.
    function unstake() external;

    /// @notice This method withdraws unstaked BOTCOIN after cooldown.
    function withdraw() external;

    /// @notice This view returns the timestamp when caller principal is withdrawable.
    function withdrawableAt(address miner) external view returns (uint64);

    /// @notice This view returns staked BOTCOIN amount for miner.
    function stakedAmount(address miner) external view returns (uint256);

    /// @notice This view returns BOTCOIN token address used by mining.
    function botcoinToken() external view returns (address);
}
