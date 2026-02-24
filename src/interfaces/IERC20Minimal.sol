// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @notice Minimal ERC20 interface containing only functions required by this project
/// @dev Identifiers remain English for ABI and compiler stability
interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
