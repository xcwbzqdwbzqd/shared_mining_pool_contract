// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MockERC20} from "./MockERC20.sol";

/// @notice This mock simulates minimal BonusEpoch behavior for tests.
contract MockBonusEpoch {
    /// @notice This immutable stores BOTCOIN token used by bonus mock.
    MockERC20 public immutable botcoin;

    /// @notice This mapping tracks whether an epoch is flagged as bonus epoch.
    mapping(uint64 => bool) public isBonusEpoch;

    /// @notice This mapping tracks whether claims are open for an epoch.
    mapping(uint64 => bool) public bonusClaimsOpen;

    /// @notice This mapping tracks bonus amount funded for each epoch.
    mapping(uint64 => uint256) public epochBonusReward;

    /// @notice This mapping tracks whether bonus reward for epoch was claimed.
    mapping(uint64 => bool) public bonusClaimed;

    /// @notice This constructor stores BOTCOIN token for transfers.
    constructor(address botcoinToken_) {
        botcoin = MockERC20(botcoinToken_);
    }

    /// @notice This view returns BOTCOIN token address for interface compatibility.
    function botcoinToken() external view returns (address) {
        return address(botcoin);
    }

    /// @notice This test helper configures bonus epoch flag.
    function setBonusEpoch(uint64 epoch, bool enabled) external {
        isBonusEpoch[epoch] = enabled;
    }

    /// @notice This test helper configures bonus claim open flag.
    function setBonusClaimsOpen(uint64 epoch, bool enabled) external {
        bonusClaimsOpen[epoch] = enabled;
    }

    /// @notice This test helper funds bonus reward for epoch by minting into bonus mock.
    function fundBonusReward(uint64 epoch, uint256 amount) external {
        botcoin.mint(address(this), amount);
        epochBonusReward[epoch] += amount;
    }

    /// @notice This function claims bonus reward for each provided epoch and transfers to caller.
    function claimBonus(uint64[] calldata epochs) external {
        for (uint256 i = 0; i < epochs.length; i++) {
            uint64 epoch = epochs[i];
            require(isBonusEpoch[epoch], "NOT_BONUS");
            require(bonusClaimsOpen[epoch], "NOT_OPEN");
            require(!bonusClaimed[epoch], "ALREADY");

            bonusClaimed[epoch] = true;
            uint256 amount = epochBonusReward[epoch];
            epochBonusReward[epoch] = 0;

            if (amount != 0) {
                botcoin.transfer(msg.sender, amount);
            }
        }
    }
}
