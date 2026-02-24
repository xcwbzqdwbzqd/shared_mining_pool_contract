// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20Minimal} from "./interfaces/IERC20Minimal.sol";

/// @notice Escrow vault used in Cutoff mode to isolate pending deposits and avoid tier pollution
/// @dev Only the pool contract can move funds from vault back to pool; users cannot interact with vault directly
contract EscrowVault {
    error OnlyPool();
    error ZeroAddress();

    IERC20Minimal public immutable token;
    address public immutable pool;

    constructor(address token_, address pool_) {
        if (token_ == address(0) || pool_ == address(0)) {
            revert ZeroAddress();
        }
        token = IERC20Minimal(token_);
        pool = pool_;
    }

    /// @notice Pool-only function that moves vault tokens back to pool during epoch rollover activation
    function transferToPool(uint256 amount) external {
        if (msg.sender != pool) {
            revert OnlyPool();
        }
        _safeTransfer(token, pool, amount);
    }

    function _safeTransfer(IERC20Minimal token_, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token_).call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            // Use generic revert here to keep vault simple; pool-side protections and errors provide the outer safety boundary
            revert();
        }
    }
}
