// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MockERC20} from "./MockERC20.sol";

/// @notice Mining mock contract for tests:
/// - credits accumulate per epoch/miner
/// - submitReceipt computes tier from miner (msg.sender) BOTCOIN balance and increases credits
/// - claim transfers preconfigured epochReward to msg.sender
contract MockMining {
    MockERC20 public immutable botcoin;

    // ---- epoch ----
    uint64 public currentEpoch;

    // ---- tier thresholds (18 decimals for botcoin) ----
    uint256 public tier1Balance;
    uint256 public tier2Balance;
    uint256 public tier3Balance;

    // ---- credits & rewards ----
    mapping(uint64 => mapping(address => uint64)) public credits;
    mapping(uint64 => uint256) public epochReward;

    // Prevent duplicate claim in mock behavior: reward is zeroed on first claim
    mapping(uint64 => bool) public epochClaimed;

    constructor(address botcoinToken_) {
        botcoin = MockERC20(botcoinToken_);

        // Use very small default thresholds for unit tests; real on-chain thresholds are much larger
        tier1Balance = 100e18;
        tier2Balance = 200e18;
        tier3Balance = 300e18;

        currentEpoch = 1;
    }

    function botcoinToken() external view returns (address) {
        return address(botcoin);
    }

    function setEpoch(uint64 epoch) external {
        currentEpoch = epoch;
    }

    function setTierBalances(uint256 t1, uint256 t2, uint256 t3) external {
        tier1Balance = t1;
        tier2Balance = t2;
        tier3Balance = t3;
    }

    function fundEpochReward(uint64 epoch, uint256 amount) external {
        // Mint BOTCOIN to mining contract so claim always has transferable balance
        botcoin.mint(address(this), amount);
        epochReward[epoch] += amount;
    }

    /// @notice This selector is allowlisted by pool as the valid submitReceiptToMining target
    function submitReceipt(bytes calldata) external {
        uint256 bal = botcoin.balanceOf(msg.sender);

        uint64 delta;
        if (bal >= tier3Balance) {
            delta = 3;
        } else if (bal >= tier2Balance) {
            delta = 2;
        } else if (bal >= tier1Balance) {
            delta = 1;
        } else {
            delta = 0;
        }

        // Do not revert when delta==0 so pool can enforce its own Δcredits>0 constraint
        if (delta != 0) {
            credits[currentEpoch][msg.sender] += delta;
        }
    }

    function claim(uint64[] calldata epochs) external {
        for (uint256 i = 0; i < epochs.length; i++) {
            uint64 e = epochs[i];
            if (epochClaimed[e]) {
                continue;
            }
            epochClaimed[e] = true;

            uint256 amount = epochReward[e];
            epochReward[e] = 0;
            if (amount != 0) {
                botcoin.transfer(msg.sender, amount);
            }
        }
    }
}
