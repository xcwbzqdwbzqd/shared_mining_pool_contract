// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MockERC20} from "./MockERC20.sol";

/// @notice This mock simulates the minimal BotcoinMiningV2 staking and reward behavior required by tests.
contract MockMiningV2 {
    /// @notice This immutable stores the BOTCOIN token used by this mock.
    MockERC20 public immutable botcoin;

    /// @notice This state tracks current mining epoch.
    uint64 public currentEpoch;

    /// @notice This state tracks unstake cooldown in seconds.
    uint64 public cooldownSeconds;

    /// @notice This mapping tracks staked principal per miner.
    mapping(address => uint256) public stakedAmount;

    /// @notice This mapping tracks withdrawable timestamp per miner.
    mapping(address => uint64) public withdrawableAt;

    /// @notice This mapping tracks earned credits by epoch and miner.
    mapping(uint64 => mapping(address => uint64)) public credits;

    /// @notice This mapping tracks regular reward amount that can be claimed for each epoch.
    mapping(uint64 => uint256) public epochReward;

    /// @notice This mapping tracks whether regular reward for epoch was already claimed.
    mapping(uint64 => bool) public epochClaimed;

    /// @notice This mapping tracks configured credit delta for submit calls by miner.
    mapping(address => uint64) public submitCreditDelta;

    /// @notice This event emits when mock epoch is updated.
    event EpochUpdated(uint64 indexed epoch);

    /// @notice This event emits when mock stake is updated.
    event StakeUpdated(address indexed miner, uint256 amount, uint256 newTotal);

    /// @notice This event emits when mock unstake is requested.
    event UnstakeRequested(address indexed miner, uint64 withdrawableAtTimestamp);

    /// @notice This event emits when mock withdraw completes.
    event WithdrawCompleted(address indexed miner, uint256 amount);

    /// @notice This constructor initializes token reference, cooldown, and default epoch.
    constructor(address botcoinToken_) {
        botcoin = MockERC20(botcoinToken_);
        cooldownSeconds = 1 days;
        currentEpoch = 1;
    }

    /// @notice This view returns BOTCOIN token address for compatibility with interface.
    function botcoinToken() external view returns (address) {
        return address(botcoin);
    }

    /// @notice This test helper sets current epoch.
    function setEpoch(uint64 epoch) external {
        currentEpoch = epoch;
        emit EpochUpdated(epoch);
    }

    /// @notice This test helper sets cooldown seconds.
    function setCooldownSeconds(uint64 value) external {
        cooldownSeconds = value;
    }

    /// @notice This test helper sets submit credit delta for a miner.
    function setSubmitCreditDelta(address miner, uint64 delta) external {
        submitCreditDelta[miner] = delta;
    }

    /// @notice This test helper sets absolute credits for epoch/miner pair.
    function setCredits(uint64 epoch, address miner, uint64 value) external {
        credits[epoch][miner] = value;
    }

    /// @notice This test helper funds regular reward for one epoch by minting into mock.
    function fundEpochReward(uint64 epoch, uint256 amount) external {
        botcoin.mint(address(this), amount);
        epochReward[epoch] += amount;
    }

    /// @notice This function stakes BOTCOIN by transferring from caller into mining mock.
    function stake(uint256 amount) external {
        botcoin.transferFrom(msg.sender, address(this), amount);
        stakedAmount[msg.sender] += amount;
        withdrawableAt[msg.sender] = 0;
        emit StakeUpdated(msg.sender, amount, stakedAmount[msg.sender]);
    }

    /// @notice This function requests full unstake and starts cooldown timer.
    function unstake() external {
        require(stakedAmount[msg.sender] != 0, "NO_STAKE");
        uint64 readyAt = uint64(block.timestamp) + cooldownSeconds;
        withdrawableAt[msg.sender] = readyAt;
        emit UnstakeRequested(msg.sender, readyAt);
    }

    /// @notice This function withdraws full principal after cooldown is complete.
    function withdraw() external {
        uint64 readyAt = withdrawableAt[msg.sender];
        require(readyAt != 0, "NOT_UNSTAKE");
        require(block.timestamp >= readyAt, "COOLDOWN");

        uint256 amount = stakedAmount[msg.sender];
        stakedAmount[msg.sender] = 0;
        withdrawableAt[msg.sender] = 0;

        botcoin.transfer(msg.sender, amount);
        emit WithdrawCompleted(msg.sender, amount);
    }

    /// @notice This function simulates submitReceipt and increases credits by configured delta.
    function submitReceipt(bytes calldata) external {
        uint64 delta = submitCreditDelta[msg.sender];
        if (delta == 0) {
            return;
        }
        credits[currentEpoch][msg.sender] += delta;
    }

    /// @notice This function claims regular reward per epoch and transfers to caller.
    function claim(uint64[] calldata epochs) external {
        for (uint256 i = 0; i < epochs.length; i++) {
            uint64 epoch = epochs[i];
            if (epochClaimed[epoch]) {
                continue;
            }

            epochClaimed[epoch] = true;
            uint256 amount = epochReward[epoch];
            epochReward[epoch] = 0;

            if (amount != 0) {
                botcoin.transfer(msg.sender, amount);
            }
        }
    }
}
