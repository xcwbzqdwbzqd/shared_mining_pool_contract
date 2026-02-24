// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @notice Minimal mining interface declaring only functions required by this project
/// @dev Critical detail: credits parameter order must be (uint64 epoch, address miner)
interface IMining {
    function currentEpoch() external view returns (uint64);

    function credits(uint64 epoch, address miner) external view returns (uint64);

    function claim(uint64[] calldata epochs) external;

    function botcoinToken() external view returns (address);
}
