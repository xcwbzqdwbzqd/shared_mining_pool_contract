// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IBonusEpoch} from "./interfaces/IBonusEpoch.sol";
import {IERC20Minimal} from "./interfaces/IERC20Minimal.sol";
import {IMiningV2} from "./interfaces/IMiningV2.sol";

/// @title SharedMiningPoolV2
/// @notice This contract implements a trust-minimized pooled BOTCOIN staking miner using BotcoinMiningV2 and BonusEpoch.
/// @dev This implementation uses epoch snapshots plus share-index accounting and permissionless principal return transitions.
contract SharedMiningPoolV2 {
    // ============================================================
    // Constants and Types
    // ============================================================

    /// @notice This precision constant scales reward-per-share values to reduce truncation error.
    uint256 public constant ACC_PRECISION = 1e36;

    /// @notice This denominator defines basis points conversion.
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice This cap defines the maximum immutable protocol fee in basis points.
    uint16 public constant MAX_FEE_BPS = 2_000;

    /// @notice This constant is the EIP-1271 success magic value.
    bytes4 public constant EIP1271_MAGICVALUE = 0x1626ba7e;

    /// @notice This constant is the EIP-1271 invalid return value.
    bytes4 public constant EIP1271_INVALID = 0xffffffff;

    /// @notice This constant stores secp256k1n/2 for strict low-s signature enforcement.
    uint256 internal constant SECP256K1N_HALF = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    /// @notice This enum defines high-level pool lifecycle phases.
    enum PoolPhase {
        ActiveStaked,
        Cooldown,
        WithdrawnIdle
    }

    /// @notice This struct stores share value that becomes effective from the stored epoch.
    struct ShareCheckpoint {
        uint64 epoch;
        uint256 shares;
    }

    // ============================================================
    // Custom Errors
    // ============================================================

    /// @notice This error indicates zero token amount where positive amount is required.
    error ZeroAmount();

    /// @notice This error indicates zero address where non-zero address is required.
    error ZeroAddress();

    /// @notice This error indicates fee basis points exceeds allowed maximum.
    error InvalidBps(uint16 provided, uint16 maxAllowed);

    /// @notice This error indicates caller is not the immutable operator address.
    error OnlyOperator();

    /// @notice This error indicates function called while pool is not in expected lifecycle phase.
    error InvalidPhase(PoolPhase expected, PoolPhase actual);

    /// @notice This error indicates deposits are not currently accepted.
    error DepositClosed(PoolPhase currentPhase);

    /// @notice This error indicates provided epoch list is empty, unsorted, or exceeds configured bound.
    error InvalidEpochList(uint256 providedLength, uint256 maxAllowed);

    /// @notice This error indicates an epoch is not finished yet and cannot be claimed.
    error EpochNotEnded(uint64 epoch, uint64 currentEpoch);

    /// @notice This error indicates regular rewards for an epoch were already processed.
    error RegularAlreadyClaimed(uint64 epoch);

    /// @notice This error indicates bonus rewards for an epoch were already processed.
    error BonusAlreadyClaimed(uint64 epoch);

    /// @notice This error indicates bonus claims are not open for the provided epoch.
    error BonusNotOpen(uint64 epoch);

    /// @notice This error indicates the provided epoch is not configured as bonus epoch.
    error NotBonusEpoch(uint64 epoch);

    /// @notice This error indicates mining calldata selector does not match immutable allowlist selector.
    error SelectorMismatch(bytes4 provided, bytes4 expected);

    /// @notice This error indicates mining credits did not strictly increase after submit forwarding.
    error CreditsDidNotIncrease(uint64 epoch, uint64 beforeCredits, uint64 afterCredits);

    /// @notice This error indicates no active shares exist for reward distribution in the epoch.
    error NoSharesForEpoch(uint64 epoch);

    /// @notice This error indicates no claimable amount exists for the requested operation.
    error NothingToClaim();

    /// @notice This error indicates a claim call returned successfully but transferred zero tokens for the epoch.
    error ZeroGrossReward(uint64 epoch);

    /// @notice This error indicates cooldown is not finished for finalize withdraw operation.
    error CooldownNotFinished(uint64 withdrawableAtTimestamp, uint64 currentTimestamp);

    /// @notice This error indicates caller requested principal withdrawal above available principal.
    error InsufficientPrincipal(uint256 requested, uint256 available);

    /// @notice This error indicates restake operation has no principal amount to stake.
    error RestakeAmountZero();

    /// @notice This error indicates restake operation cannot proceed because available balance is below required principal.
    error RestakeInsufficientBalance(uint256 requiredPrincipal, uint256 availableForStake);

    /// @notice This error indicates epoch boundary required for unstake is not reached yet.
    error EpochBoundaryNotReached(uint64 currentEpoch, uint64 minimumAllowedEpoch);

    /// @notice This error indicates mining call reverted while forwarding submit calldata.
    error MiningCallFailed();

    /// @notice This error indicates reentrancy has been detected.
    error ReentrantCall();

    /// @notice This error indicates out-of-order checkpoint insertion that violates monotonic structure.
    error CheckpointOutOfOrder(uint64 epoch, uint64 lastEpoch, uint64 secondLastEpoch);

    // ============================================================
    // Events
    // ============================================================

    /// @notice This event records a user principal deposit queued for next epoch activation.
    event Deposited(address indexed user, uint256 amount, uint64 indexed currentEpoch, uint64 indexed activationEpoch);

    /// @notice This event records activation of queued shares into active share set at epoch rollover.
    event SharesActivated(uint64 indexed epoch, uint256 activatedShares, uint256 newTotalActiveShares);

    /// @notice This event records operator receipt forwarding and delta credits observed on mining contract.
    event ReceiptForwarded(uint64 indexed epoch, uint64 beforeCredits, uint64 afterCredits, uint256 deltaCredits);

    /// @notice This event records regular epoch reward claim and fee split.
    event RegularRewardsClaimed(
        uint64 indexed epoch, uint256 grossReward, uint256 feeAmount, uint256 netReward, address indexed feeRecipient
    );

    /// @notice This event records bonus epoch reward claim and fee split.
    event BonusRewardsClaimed(
        uint64 indexed epoch, uint256 grossReward, uint256 feeAmount, uint256 netReward, address indexed feeRecipient
    );

    /// @notice This event records user reward claim payout for one epoch.
    event UserRewardsClaimed(address indexed user, address indexed to, uint64 indexed epoch, uint256 payoutAmount);

    /// @notice This event records permissionless unstake request execution.
    event UnstakeRequested(uint64 indexed epoch, address indexed caller);

    /// @notice This event records permissionless finalize withdraw execution after cooldown.
    event UnstakeFinalized(uint64 indexed epoch, address indexed caller);

    /// @notice This event records permissionless restake execution.
    event Restaked(uint64 indexed epoch, uint256 amount, address indexed caller);

    /// @notice This event records permissionless active-phase principal top-up staking execution.
    event PrincipalStaked(uint64 indexed epoch, uint256 amount, address indexed caller);

    /// @notice This event records principal withdrawal execution by depositor.
    event PrincipalWithdrawn(address indexed user, address indexed to, uint256 amount, uint64 indexed epoch);

    // ============================================================
    // Immutable Configuration
    // ============================================================

    /// @notice This immutable references BotcoinMiningV2 contract.
    IMiningV2 public immutable mining;

    /// @notice This immutable references BonusEpoch contract.
    IBonusEpoch public immutable bonusEpoch;

    /// @notice This immutable references BOTCOIN token contract.
    IERC20Minimal public immutable botcoin;

    /// @notice This immutable stores operator address used for submit forwarding only.
    address public immutable operator;

    /// @notice This immutable stores recipient of immutable fee.
    address public immutable feeRecipient;

    /// @notice This immutable stores fee basis points applied to regular and bonus inflows.
    uint16 public immutable feeBps;

    /// @notice This immutable stores expected submit function selector for forwarded mining calldata.
    bytes4 public immutable receiptSubmitSelector;

    /// @notice This immutable stores the maximum epoch list length allowed per claim call.
    uint256 public immutable maxEpochsPerClaim;

    // ============================================================
    // Global State
    // ============================================================

    /// @notice This state stores current lifecycle phase for strict function gating.
    PoolPhase public phase;

    /// @notice This state stores the latest epoch already processed for share activation.
    uint64 public lastSettledEpoch;

    /// @notice This state stores the epoch when unstake was most recently requested.
    uint64 public lastUnstakeEpoch;

    /// @notice This state stores the epoch when restake was most recently executed.
    uint64 public lastRestakeEpoch;

    /// @notice This state stores the earliest epoch at which unstake is allowed.
    uint64 public unstakeAvailableAtEpoch;

    /// @notice This state stores total active shares used for future epoch reward distribution.
    uint256 public totalActiveShares;

    /// @notice This state stores total principal liabilities owed to all users.
    uint256 public totalPrincipalLiability;

    /// @notice This state stores total net rewards accrued into user-claimable accounting.
    uint256 public totalNetRewardsAccrued;

    /// @notice This state stores total rewards already paid out to users.
    uint256 public totalRewardsPaid;

    /// @notice This mapping stores global shares queued for activation at specific epoch.
    mapping(uint64 => uint256) public scheduledActivationShares;

    /// @notice This mapping stores per-user queued shares for a specific activation epoch.
    mapping(address => mapping(uint64 => uint256)) public userPendingSharesByEpoch;

    /// @notice This mapping stores per-user principal liabilities tracked on-chain.
    mapping(address => uint256) public userPrincipal;

    /// @notice This mapping stores total principal already withdrawn by each user.
    mapping(address => uint256) public userWithdrawnPrincipal;

    /// @notice This mapping stores per-epoch accumulated reward per share index.
    mapping(uint64 => uint256) public epochAccRewardPerShare;

    /// @notice This mapping stores per-epoch net regular reward added to accounting.
    mapping(uint64 => uint256) public epochRegularNetReward;

    /// @notice This mapping stores per-epoch net bonus reward added to accounting.
    mapping(uint64 => uint256) public epochBonusNetReward;

    /// @notice This mapping stores per-epoch total net reward (regular + bonus).
    mapping(uint64 => uint256) public epochTotalNetReward;

    /// @notice This mapping stores whether regular reward flow for epoch has been processed.
    mapping(uint64 => bool) public epochRegularClaimed;

    /// @notice This mapping stores whether bonus reward flow for epoch has been processed.
    mapping(uint64 => bool) public epochBonusClaimed;

    /// @notice This mapping stores total receipt credits submitted by pool for each epoch.
    mapping(uint64 => uint256) public epochCredits;

    /// @notice This mapping stores per-user per-epoch reward debt for incremental claiming.
    mapping(address => mapping(uint64 => uint256)) public userRewardDebt;

    /// @notice This mapping stores per-user per-epoch cumulative claimed amount for observability.
    mapping(address => mapping(uint64 => uint256)) public userClaimedReward;

    /// @notice This mapping stores per-user share checkpoints used for epoch snapshot lookup.
    mapping(address => ShareCheckpoint[]) internal _userShareCheckpoints;

    /// @notice This array stores total share checkpoints used for epoch snapshot lookup.
    ShareCheckpoint[] internal _totalShareCheckpoints;

    /// @notice This status flag stores local non-reentrancy state.
    uint256 private _reentrancyStatus;

    // ============================================================
    // Modifiers
    // ============================================================

    /// @notice This modifier blocks nested entry for protected functions.
    modifier nonReentrant() {
        if (_reentrancyStatus == 2) {
            revert ReentrantCall();
        }
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    /// @notice This modifier restricts call access to immutable operator only.
    modifier onlyOperator() {
        if (msg.sender != operator) {
            revert OnlyOperator();
        }
        _;
    }

    // ============================================================
    // Constructor
    // ============================================================

    /// @notice This constructor initializes immutable references and bootstrap state.
    constructor(
        address mining_,
        address bonusEpoch_,
        address operator_,
        address feeRecipient_,
        uint16 feeBps_,
        bytes4 receiptSubmitSelector_,
        uint256 maxEpochsPerClaim_
    ) {
        if (
            mining_ == address(0) || bonusEpoch_ == address(0) || operator_ == address(0) || feeRecipient_ == address(0)
        ) {
            revert ZeroAddress();
        }
        if (feeBps_ > MAX_FEE_BPS) {
            revert InvalidBps(feeBps_, MAX_FEE_BPS);
        }
        if (maxEpochsPerClaim_ == 0) {
            revert ZeroAmount();
        }

        mining = IMiningV2(mining_);
        bonusEpoch = IBonusEpoch(bonusEpoch_);
        operator = operator_;
        feeRecipient = feeRecipient_;
        feeBps = feeBps_;
        receiptSubmitSelector = receiptSubmitSelector_;
        maxEpochsPerClaim = maxEpochsPerClaim_;

        address tokenFromMining = IMiningV2(mining_).botcoinToken();
        address tokenFromBonus = IBonusEpoch(bonusEpoch_).botcoinToken();
        if (tokenFromMining == address(0) || tokenFromBonus == address(0) || tokenFromMining != tokenFromBonus) {
            revert ZeroAddress();
        }
        botcoin = IERC20Minimal(tokenFromMining);

        uint64 current = IMiningV2(mining_).currentEpoch();
        phase = PoolPhase.ActiveStaked;
        lastSettledEpoch = current;
        lastUnstakeEpoch = current;
        lastRestakeEpoch = current;
        unstakeAvailableAtEpoch = current + 1;

        _totalShareCheckpoints.push(ShareCheckpoint({epoch: current, shares: 0}));

        _reentrancyStatus = 1;
    }

    // ============================================================
    // EIP-1271
    // ============================================================

    /// @notice This function validates digest+signature against immutable operator using strict ECDSA checks.
    /// @dev This function must validate coordinator-provided digest directly and must not hash raw message again.
    function isValidSignature(bytes32 digest, bytes calldata signature) external view returns (bytes4) {
        if (signature.length != 65) {
            return EIP1271_INVALID;
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        if (v < 27) {
            v += 27;
        }
        if (v != 27 && v != 28) {
            return EIP1271_INVALID;
        }
        if (uint256(s) > SECP256K1N_HALF) {
            return EIP1271_INVALID;
        }

        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0)) {
            return EIP1271_INVALID;
        }

        return recovered == operator ? EIP1271_MAGICVALUE : EIP1271_INVALID;
    }

    // ============================================================
    // User Principal Actions
    // ============================================================

    /// @notice This function deposits BOTCOIN and queues shares for next epoch activation.
    function deposit(uint256 amount) external nonReentrant {
        if (phase != PoolPhase.ActiveStaked) {
            revert DepositClosed(phase);
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        _checkpointEpoch();

        uint64 current = _currentEpoch();
        uint64 activationEpoch = current + 1;

        _safeTransferFrom(botcoin, msg.sender, address(this), amount);

        scheduledActivationShares[activationEpoch] += amount;
        userPendingSharesByEpoch[msg.sender][activationEpoch] += amount;

        uint256 sharesAtActivation = _getUserSharesAtEpoch(msg.sender, activationEpoch);
        _writeUserSharesCheckpoint(msg.sender, activationEpoch, sharesAtActivation + amount);

        userPrincipal[msg.sender] += amount;
        totalPrincipalLiability += amount;

        emit Deposited(msg.sender, amount, current, activationEpoch);
    }

    /// @notice This function allows user to withdraw principal only after pool principal is back from mining.
    function withdrawPrincipal(uint256 amount, address to) external nonReentrant {
        if (phase != PoolPhase.WithdrawnIdle) {
            revert InvalidPhase(PoolPhase.WithdrawnIdle, phase);
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (to == address(0)) {
            revert ZeroAddress();
        }

        _checkpointEpoch();

        uint256 availablePrincipal = userPrincipal[msg.sender];
        if (amount > availablePrincipal) {
            revert InsufficientPrincipal(amount, availablePrincipal);
        }

        userPrincipal[msg.sender] = availablePrincipal - amount;
        userWithdrawnPrincipal[msg.sender] += amount;
        totalPrincipalLiability -= amount;

        uint64 current = _currentEpoch();
        uint256 userSharesCurrent = _getUserSharesAtEpoch(msg.sender, current);
        if (amount > userSharesCurrent) {
            revert InsufficientPrincipal(amount, userSharesCurrent);
        }

        _writeUserSharesCheckpoint(msg.sender, current, userSharesCurrent - amount);

        totalActiveShares -= amount;
        _writeTotalSharesCheckpoint(current, totalActiveShares);

        _safeTransfer(botcoin, to, amount);

        emit PrincipalWithdrawn(msg.sender, to, amount, current);
    }

    // ============================================================
    // Permissionless State Transitions
    // ============================================================

    /// @notice This function requests full unstake at or after configured epoch boundary.
    function unstakeAtEpochEnd() external nonReentrant {
        if (phase != PoolPhase.ActiveStaked) {
            revert InvalidPhase(PoolPhase.ActiveStaked, phase);
        }

        _checkpointEpoch();

        if (mining.stakedAmount(address(this)) == 0) {
            revert RestakeAmountZero();
        }

        uint64 current = _currentEpoch();
        if (current < unstakeAvailableAtEpoch) {
            revert EpochBoundaryNotReached(current, unstakeAvailableAtEpoch);
        }

        mining.unstake();

        phase = PoolPhase.Cooldown;
        lastUnstakeEpoch = current;

        emit UnstakeRequested(current, msg.sender);
    }

    /// @notice This function finalizes unstake after cooldown and returns principal from mining to pool custody.
    function finalizeWithdraw() external nonReentrant {
        if (phase != PoolPhase.Cooldown) {
            revert InvalidPhase(PoolPhase.Cooldown, phase);
        }

        _checkpointEpoch();

        uint64 readyAt = mining.withdrawableAt(address(this));
        uint64 nowTs = uint64(block.timestamp);
        if (readyAt == 0 || nowTs < readyAt) {
            revert CooldownNotFinished(readyAt, nowTs);
        }

        mining.withdraw();

        phase = PoolPhase.WithdrawnIdle;

        emit UnstakeFinalized(_currentEpoch(), msg.sender);
    }

    /// @notice This function permissionlessly restakes principal liabilities while preserving reward reserve liquidity.
    function restake() external nonReentrant {
        if (phase != PoolPhase.WithdrawnIdle) {
            revert InvalidPhase(PoolPhase.WithdrawnIdle, phase);
        }

        _checkpointEpoch();

        if (totalPrincipalLiability == 0) {
            revert RestakeAmountZero();
        }

        uint256 stakedDelta = _stakeToPrincipalTarget();

        phase = PoolPhase.ActiveStaked;

        uint64 current = _currentEpoch();
        lastRestakeEpoch = current;
        unstakeAvailableAtEpoch = current + 1;

        emit Restaked(current, stakedDelta, msg.sender);
    }

    /// @notice This function permissionlessly stakes principal delta while pool remains in active phase.
    function stakePrincipal() external nonReentrant {
        if (phase != PoolPhase.ActiveStaked) {
            revert InvalidPhase(PoolPhase.ActiveStaked, phase);
        }

        _checkpointEpoch();

        uint256 stakedDelta = _stakeToPrincipalTarget();
        if (stakedDelta == 0) {
            revert RestakeAmountZero();
        }

        emit PrincipalStaked(_currentEpoch(), stakedDelta, msg.sender);
    }

    // ============================================================
    // Operator Forwarding
    // ============================================================

    /// @notice This function forwards allowed receipt calldata to mining and enforces positive credit delta.
    function submitReceiptToMining(bytes calldata miningCalldata) external onlyOperator nonReentrant {
        if (phase != PoolPhase.ActiveStaked) {
            revert InvalidPhase(PoolPhase.ActiveStaked, phase);
        }

        _checkpointEpoch();

        if (miningCalldata.length < 4) {
            revert SelectorMismatch(bytes4(0), receiptSubmitSelector);
        }

        bytes4 selector;
        assembly {
            selector := calldataload(miningCalldata.offset)
        }
        if (selector != receiptSubmitSelector) {
            revert SelectorMismatch(selector, receiptSubmitSelector);
        }

        uint64 current = _currentEpoch();
        if (totalActiveShares == 0) {
            revert NoSharesForEpoch(current);
        }
        uint64 beforeCredits = mining.credits(current, address(this));

        (bool ok,) = address(mining).call(miningCalldata);
        if (!ok) {
            revert MiningCallFailed();
        }

        uint64 afterCredits = mining.credits(current, address(this));
        if (afterCredits <= beforeCredits) {
            revert CreditsDidNotIncrease(current, beforeCredits, afterCredits);
        }

        uint256 deltaCredits = uint256(afterCredits - beforeCredits);
        epochCredits[current] += deltaCredits;

        emit ReceiptForwarded(current, beforeCredits, afterCredits, deltaCredits);
    }

    // ============================================================
    // Permissionless Reward Claims
    // ============================================================

    /// @notice This function permissionlessly claims regular mining rewards for ended epochs and updates epoch indices.
    function claimRewards(uint64[] calldata epochs) external nonReentrant {
        _checkpointEpoch();
        _validateEpochList(epochs);

        uint64 current = _currentEpoch();

        for (uint256 i = 0; i < epochs.length; i++) {
            uint64 epoch = epochs[i];
            if (epoch >= current) {
                revert EpochNotEnded(epoch, current);
            }
            if (epochRegularClaimed[epoch]) {
                revert RegularAlreadyClaimed(epoch);
            }

            uint256 beforeBalance = botcoin.balanceOf(address(this));
            uint64[] memory singleEpoch = new uint64[](1);
            singleEpoch[0] = epoch;
            mining.claim(singleEpoch);
            uint256 grossReward = botcoin.balanceOf(address(this)) - beforeBalance;
            if (grossReward == 0) {
                revert ZeroGrossReward(epoch);
            }

            uint256 feeAmount = (grossReward * feeBps) / BPS_DENOMINATOR;
            uint256 netReward = grossReward - feeAmount;

            epochRegularClaimed[epoch] = true;
            epochRegularNetReward[epoch] = netReward;

            _recordEpochReward(epoch, netReward);

            if (feeAmount != 0) {
                _safeTransfer(botcoin, feeRecipient, feeAmount);
            }

            emit RegularRewardsClaimed(epoch, grossReward, feeAmount, netReward, feeRecipient);
        }
    }

    /// @notice This function permissionlessly claims bonus rewards for eligible epochs and updates epoch indices.
    function claimBonusRewards(uint64[] calldata epochs) external nonReentrant {
        _checkpointEpoch();
        _validateEpochList(epochs);

        for (uint256 i = 0; i < epochs.length; i++) {
            uint64 epoch = epochs[i];
            if (epochBonusClaimed[epoch]) {
                revert BonusAlreadyClaimed(epoch);
            }
            if (!bonusEpoch.isBonusEpoch(epoch)) {
                revert NotBonusEpoch(epoch);
            }
            if (!bonusEpoch.bonusClaimsOpen(epoch)) {
                revert BonusNotOpen(epoch);
            }

            uint256 beforeBalance = botcoin.balanceOf(address(this));
            uint64[] memory singleEpoch = new uint64[](1);
            singleEpoch[0] = epoch;
            bonusEpoch.claimBonus(singleEpoch);
            uint256 grossReward = botcoin.balanceOf(address(this)) - beforeBalance;
            if (grossReward == 0) {
                revert ZeroGrossReward(epoch);
            }

            uint256 feeAmount = (grossReward * feeBps) / BPS_DENOMINATOR;
            uint256 netReward = grossReward - feeAmount;

            epochBonusClaimed[epoch] = true;
            epochBonusNetReward[epoch] = netReward;

            _recordEpochReward(epoch, netReward);

            if (feeAmount != 0) {
                _safeTransfer(botcoin, feeRecipient, feeAmount);
            }

            emit BonusRewardsClaimed(epoch, grossReward, feeAmount, netReward, feeRecipient);
        }
    }

    /// @notice This function allows user to claim owed rewards for a strictly increasing epoch list.
    function claimUser(uint64[] calldata epochs, address to) external nonReentrant {
        if (to == address(0)) {
            revert ZeroAddress();
        }

        _checkpointEpoch();
        _validateEpochList(epochs);

        uint256 payoutTotal = 0;

        for (uint256 i = 0; i < epochs.length; i++) {
            uint64 epoch = epochs[i];
            uint256 shares = _getUserSharesAtEpoch(msg.sender, epoch);
            if (shares == 0) {
                continue;
            }

            uint256 accrued = (shares * epochAccRewardPerShare[epoch]) / ACC_PRECISION;
            uint256 debt = userRewardDebt[msg.sender][epoch];
            if (accrued <= debt) {
                continue;
            }

            uint256 pending = accrued - debt;
            userRewardDebt[msg.sender][epoch] = accrued;
            userClaimedReward[msg.sender][epoch] += pending;
            payoutTotal += pending;

            emit UserRewardsClaimed(msg.sender, to, epoch, pending);
        }

        if (payoutTotal == 0) {
            revert NothingToClaim();
        }

        totalRewardsPaid += payoutTotal;
        _safeTransfer(botcoin, to, payoutTotal);
    }

    // ============================================================
    // View Helpers
    // ============================================================

    /// @notice This function returns active user shares at target epoch.
    function userSharesAtEpoch(address user, uint64 epoch) external view returns (uint256) {
        return _getUserSharesAtEpoch(user, epoch);
    }

    /// @notice This function returns total shares at target epoch.
    function totalSharesAtEpoch(uint64 epoch) external view returns (uint256) {
        return _getTotalSharesAtEpoch(epoch);
    }

    /// @notice This function returns current reward reserve that should remain liquid for user claims.
    function rewardReserve() external view returns (uint256) {
        return totalNetRewardsAccrued - totalRewardsPaid;
    }

    /// @notice This function exposes manual epoch checkpointing for off-chain keepers and tests.
    function checkpointEpoch() external nonReentrant {
        _checkpointEpoch();
    }

    // ============================================================
    // Internal Accounting
    // ============================================================

    /// @notice This function records net reward into per-epoch index accounting.
    function _recordEpochReward(uint64 epoch, uint256 netReward) internal {
        if (netReward == 0) {
            return;
        }

        uint256 shares = _getTotalSharesAtEpoch(epoch);
        if (shares == 0) {
            revert NoSharesForEpoch(epoch);
        }

        uint256 deltaAcc = (netReward * ACC_PRECISION) / shares;
        epochAccRewardPerShare[epoch] += deltaAcc;
        epochTotalNetReward[epoch] += netReward;
        totalNetRewardsAccrued += netReward;
    }

    /// @notice This function stakes the minimum delta required for mining staked principal to match principal liabilities.
    function _stakeToPrincipalTarget() internal returns (uint256) {
        uint256 targetPrincipal = totalPrincipalLiability;
        uint256 alreadyStaked = mining.stakedAmount(address(this));
        if (alreadyStaked >= targetPrincipal) {
            return 0;
        }

        uint256 deltaToStake = targetPrincipal - alreadyStaked;
        uint256 balance = botcoin.balanceOf(address(this));
        uint256 rewardReserveAmount = totalNetRewardsAccrued - totalRewardsPaid;

        uint256 availableForStake = 0;
        if (balance > rewardReserveAmount) {
            availableForStake = balance - rewardReserveAmount;
        }

        if (availableForStake < deltaToStake) {
            revert RestakeInsufficientBalance(deltaToStake, availableForStake);
        }

        _safeApprove(botcoin, address(mining), 0);
        _safeApprove(botcoin, address(mining), deltaToStake);
        mining.stake(deltaToStake);

        return deltaToStake;
    }

    /// @notice This function validates epoch list length and strict increasing ordering.
    function _validateEpochList(uint64[] calldata epochs) internal view {
        uint256 length = epochs.length;
        if (length == 0 || length > maxEpochsPerClaim) {
            revert InvalidEpochList(length, maxEpochsPerClaim);
        }

        uint64 prev = 0;
        for (uint256 i = 0; i < length; i++) {
            uint64 epoch = epochs[i];
            if (i != 0 && epoch <= prev) {
                revert InvalidEpochList(length, maxEpochsPerClaim);
            }
            prev = epoch;
        }
    }

    /// @notice This function returns current epoch from mining source of truth.
    function _currentEpoch() internal view returns (uint64) {
        return mining.currentEpoch();
    }

    /// @notice This function processes queued global share activations for newly entered epochs.
    function _checkpointEpoch() internal {
        uint64 current = _currentEpoch();
        uint64 last = lastSettledEpoch;

        if (current <= last) {
            return;
        }

        // This is intentionally O(1) and does not scan all intermediate epochs.
        //
        // Reason:
        // - `scheduledActivationShares` is only ever written by `deposit()`.
        // - `deposit()` always schedules activation for `currentEpoch + 1`.
        // - Every external entrypoint calls `_checkpointEpoch()` before writing new activations.
        //
        // Therefore, for any call where `current > last`, the only epoch in (last, current] that can
        // possibly have a non-zero scheduled activation is `last + 1`.
        uint64 activationEpoch = last + 1;
        uint256 activation = scheduledActivationShares[activationEpoch];
        if (activation != 0) {
            scheduledActivationShares[activationEpoch] = 0;
            totalActiveShares += activation;
            _writeTotalSharesCheckpoint(activationEpoch, totalActiveShares);
            emit SharesActivated(activationEpoch, activation, totalActiveShares);
        }

        lastSettledEpoch = current;
    }

    /// @notice This function returns effective user shares at target epoch using binary search over checkpoints.
    function _getUserSharesAtEpoch(address user, uint64 epoch) internal view returns (uint256) {
        ShareCheckpoint[] storage checkpoints = _userShareCheckpoints[user];
        uint256 count = checkpoints.length;
        if (count == 0) {
            return 0;
        }

        if (checkpoints[count - 1].epoch <= epoch) {
            return checkpoints[count - 1].shares;
        }
        if (checkpoints[0].epoch > epoch) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = count - 1;
        while (low + 1 < high) {
            uint256 mid = (low + high) / 2;
            if (checkpoints[mid].epoch <= epoch) {
                low = mid;
            } else {
                high = mid;
            }
        }

        return checkpoints[low].shares;
    }

    /// @notice This function returns effective total shares at target epoch using binary search over total checkpoints.
    function _getTotalSharesAtEpoch(uint64 epoch) internal view returns (uint256) {
        ShareCheckpoint[] storage checkpoints = _totalShareCheckpoints;
        uint256 count = checkpoints.length;
        if (count == 0) {
            return 0;
        }

        if (checkpoints[count - 1].epoch <= epoch) {
            return checkpoints[count - 1].shares;
        }
        if (checkpoints[0].epoch > epoch) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = count - 1;
        while (low + 1 < high) {
            uint256 mid = (low + high) / 2;
            if (checkpoints[mid].epoch <= epoch) {
                low = mid;
            } else {
                high = mid;
            }
        }

        return checkpoints[low].shares;
    }

    /// @notice This function writes or inserts user share checkpoint while preserving sorted checkpoint semantics.
    function _writeUserSharesCheckpoint(address user, uint64 epoch, uint256 shares) internal {
        ShareCheckpoint[] storage checkpoints = _userShareCheckpoints[user];
        uint256 count = checkpoints.length;

        if (count == 0) {
            checkpoints.push(ShareCheckpoint({epoch: epoch, shares: shares}));
            return;
        }

        uint64 lastEpoch = checkpoints[count - 1].epoch;
        if (epoch > lastEpoch) {
            checkpoints.push(ShareCheckpoint({epoch: epoch, shares: shares}));
            return;
        }
        if (epoch == lastEpoch) {
            checkpoints[count - 1].shares = shares;
            return;
        }

        if (count == 1) {
            ShareCheckpoint memory tail = checkpoints[0];
            checkpoints.push(tail);
            checkpoints[0] = ShareCheckpoint({epoch: epoch, shares: shares});
            return;
        }

        uint64 secondLastEpoch = checkpoints[count - 2].epoch;
        if (epoch == secondLastEpoch) {
            checkpoints[count - 2].shares = shares;
            return;
        }
        if (epoch < secondLastEpoch) {
            revert CheckpointOutOfOrder(epoch, lastEpoch, secondLastEpoch);
        }

        ShareCheckpoint memory previousTail = checkpoints[count - 1];
        checkpoints.push(previousTail);
        checkpoints[count - 1] = ShareCheckpoint({epoch: epoch, shares: shares});
    }

    /// @notice This function writes or inserts total share checkpoint while preserving sorted checkpoint semantics.
    function _writeTotalSharesCheckpoint(uint64 epoch, uint256 shares) internal {
        ShareCheckpoint[] storage checkpoints = _totalShareCheckpoints;
        uint256 count = checkpoints.length;

        if (count == 0) {
            checkpoints.push(ShareCheckpoint({epoch: epoch, shares: shares}));
            return;
        }

        uint64 lastEpoch = checkpoints[count - 1].epoch;
        if (epoch > lastEpoch) {
            checkpoints.push(ShareCheckpoint({epoch: epoch, shares: shares}));
            return;
        }
        if (epoch == lastEpoch) {
            checkpoints[count - 1].shares = shares;
            return;
        }

        if (count == 1) {
            ShareCheckpoint memory tail = checkpoints[0];
            checkpoints.push(tail);
            checkpoints[0] = ShareCheckpoint({epoch: epoch, shares: shares});
            return;
        }

        uint64 secondLastEpoch = checkpoints[count - 2].epoch;
        if (epoch == secondLastEpoch) {
            checkpoints[count - 2].shares = shares;
            return;
        }
        if (epoch < secondLastEpoch) {
            revert CheckpointOutOfOrder(epoch, lastEpoch, secondLastEpoch);
        }

        ShareCheckpoint memory previousTail = checkpoints[count - 1];
        checkpoints.push(previousTail);
        checkpoints[count - 1] = ShareCheckpoint({epoch: epoch, shares: shares});
    }

    /// @notice This function performs safe ERC20 transfer with optional return handling.
    function _safeTransfer(IERC20Minimal token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert();
        }
    }

    /// @notice This function performs safe ERC20 transferFrom with optional return handling.
    function _safeTransferFrom(IERC20Minimal token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert();
        }
    }

    /// @notice This function performs safe ERC20 approve with optional return handling.
    function _safeApprove(IERC20Minimal token, address spender, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20Minimal.approve.selector, spender, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert();
        }
    }
}
