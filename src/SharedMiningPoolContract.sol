// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {EscrowVault} from "./EscrowVault.sol";
import {IERC20Minimal} from "./interfaces/IERC20Minimal.sol";
import {IMining} from "./interfaces/IMining.sol";

/// @title SharedMiningPoolContract
/// @notice Shared BOTCOIN mining pool (miner is this contract), distributing rewards by credit production time
/// @dev
/// - Security first: principal can only be withdrawn by depositors under lock rules; operator can never move principal
/// - Minimal trust: the only trust point is operator solving and forwarding receipts; allocation and claiming stay on-chain
/// - Scalable: submitReceipt never iterates depositors; all accounting uses index-debt settlement
contract SharedMiningPoolContract {
    // ============
    // ========
    //  Constants / Types
    // ========
    // ============

    /// @notice Precision for credits-per-share (higher means lower division loss; 1e36 is still safe in 256-bit arithmetic)
    uint256 public constant ACC_PRECISION = 1e36;

    /// @notice BPS denominator
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Fee cap (can be tightened later in code; immutable avoids post-deploy fee rug)
    uint16 public constant MAX_FEE_BPS = 2_000; // 20%

    /// @notice EIP-1271 magic value
    bytes4 public constant EIP1271_MAGICVALUE = 0x1626ba7e;
    bytes4 public constant EIP1271_INVALID = 0xffffffff;

    /// @dev secp256k1 half order used for low-s validation (EIP-2)
    uint256 internal constant SECP256K1N_HALF = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    /// @notice Deposit activation mode (fixed at deployment via immutable)
    enum DepositMode {
        Immediate,
        NextEpochCutoff
    }

    /// @dev User share checkpoint: shares become effective from an epoch (absolute value, not delta)
    struct ShareCheckpoint {
        uint64 epoch;
        uint256 shares;
    }

    // =====================
    // ========
    //  Custom Errors
    // ========
    // =====================

    error ZeroAmount();
    error ZeroAddress();
    error InvalidBps(uint16 bps, uint16 maxBps);
    error InvalidSelector(bytes4 provided, bytes4 expected);
    error OnlyOperator();
    error EpochNotEnded(uint64 epoch, uint64 currentEpoch);
    error WithdrawLocked(uint64 effectiveEpoch, uint64 currentEpoch);
    error NoActiveShares(uint64 epoch);
    error CreditsDidNotIncrease(uint64 epoch, uint64 beforeCredits, uint64 afterCredits);
    error EpochAlreadyClaimed(uint64 epoch);
    error EpochNotClaimed(uint64 epoch);
    error EpochsNotStrictlyIncreasing();
    error TooManyEpochs(uint256 provided, uint256 max);
    error NothingToClaim();
    error MiningCallFailed();
    error CheckpointOutOfOrder(uint64 epoch, uint64 lastEpoch, uint64 secondLastEpoch);

    // =================
    // ========
    //  Events
    // ========
    // =================

    event Deposited(address indexed user, uint256 amount, uint64 indexed currentEpoch, uint64 indexed effectiveEpoch);
    event Withdrawn(address indexed user, address indexed to, uint256 amount, uint64 indexed currentEpoch);
    event RolloverExecuted(uint64 indexed activatedEpoch, uint256 activatedAmount);
    event ReceiptForwarded(
        uint64 indexed epoch,
        uint256 deltaCredits,
        uint256 totalActiveShares,
        uint256 newEpochPoolCredits,
        uint256 newEpochAccCreditsPerShare
    );
    event EpochRewardsClaimed(
        uint64 indexed epoch, uint256 grossBotcoin, uint256 feeBotcoin, uint256 netBotcoin, address indexed feeRecipient
    );
    event UserRewardsClaimed(address indexed user, address indexed to, uint64 indexed epoch, uint256 payoutBotcoin);

    // ======================
    // ========
    //  Immutable Configuration
    // ========
    // ======================

    IMining public immutable mining;
    IERC20Minimal public immutable botcoinToken;
    address public immutable operator;

    address public immutable feeRecipient;
    uint16 public immutable feeBps;

    DepositMode public immutable depositMode;
    bytes4 public immutable receiptSubmitSelector;
    uint256 public immutable maxEpochsPerClaim;

    EscrowVault public immutable vault; // address(0) in Immediate mode

    // ==========================
    // ========
    //  Global State (shares/epoch)
    // ========
    // ==========================

    /// @notice Total active shares in the current epoch (pending shares excluded in Cutoff mode)
    uint256 public totalActiveShares;

    /// @notice Cutoff mode: shares to move from vault into pool when an epoch is activated (1 share == 1 BOTCOIN wei)
    mapping(uint64 => uint256) public scheduledActivationShares;

    /// @notice Epoch of the last rollover/checkpoint execution (for Cutoff mode handling)
    uint64 public lastCheckpointEpoch;

    // =========================
    // ========
    //  Credits Indices (per epoch)
    // ========
    // =========================

    mapping(uint64 => uint256) public epochAccCreditsPerShare; // scaled by ACC_PRECISION
    mapping(uint64 => uint256) public epochPoolCredits; // unscaled credits (sum of deltas)

    // user -> epoch -> scaled credits debt
    mapping(address => mapping(uint64 => uint256)) public userEpochCreditDebtScaled;

    // user -> epoch -> scaled credits accrued (credits * ACC_PRECISION)
    mapping(address => mapping(uint64 => uint256)) public userEpochCreditsScaled;

    // =========================
    // ========
    //  Rewards (BOTCOIN) per epoch
    // ========
    // =========================

    mapping(uint64 => bool) public epochRewardsClaimed;
    mapping(uint64 => uint256) public epochBotcoinNet;
    mapping(uint64 => uint256) public epochBotcoinPaid;

    // =====================
    // ========
    //  User Share Checkpoints
    // ========
    // =====================

    mapping(address => ShareCheckpoint[]) internal _shareCheckpoints;

    /// @notice user -> epoch -> principal amount that becomes effective in this epoch (locked during this epoch)
    mapping(address => mapping(uint64 => uint256)) public userEpochPrincipal;

    // =====================
    // ========
    //  ReentrancyGuard
    // ========
    // =====================

    uint256 private _reentrancyStatus;

    modifier nonReentrant() {
        // 1 = not entered; 2 = entered
        if (_reentrancyStatus == 2) {
            revert();
        }
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) {
            revert OnlyOperator();
        }
        _;
    }

    constructor(
        address miningContract_,
        address operator_,
        address feeRecipient_,
        uint16 feeBps_,
        DepositMode depositMode_,
        bytes4 receiptSubmitSelector_,
        uint256 maxEpochsPerClaim_
    ) {
        if (miningContract_ == address(0) || operator_ == address(0) || feeRecipient_ == address(0)) {
            revert ZeroAddress();
        }
        if (feeBps_ > MAX_FEE_BPS) {
            revert InvalidBps(feeBps_, MAX_FEE_BPS);
        }
        if (maxEpochsPerClaim_ == 0) {
            revert ZeroAmount();
        }

        mining = IMining(miningContract_);
        operator = operator_;
        feeRecipient = feeRecipient_;
        feeBps = feeBps_;

        depositMode = depositMode_;
        receiptSubmitSelector = receiptSubmitSelector_;
        maxEpochsPerClaim = maxEpochsPerClaim_;

        address token = IMining(miningContract_).botcoinToken();
        if (token == address(0)) {
            revert ZeroAddress();
        }
        botcoinToken = IERC20Minimal(token);

        // Deploy vault only in Cutoff mode; set vault to zero address in Immediate mode
        if (depositMode_ == DepositMode.NextEpochCutoff) {
            vault = new EscrowVault(token, address(this));
        } else {
            vault = EscrowVault(address(0));
        }

        // Initialize checkpoint epoch to avoid a meaningless long catch-up loop on first checkpoint
        lastCheckpointEpoch = IMining(miningContract_).currentEpoch();

        // Initialize ReentrancyGuard to 1 (not entered)
        _reentrancyStatus = 1;
    }

    // ==================
    // ========
    //  EIP-1271
    // ========
    // ==================

    /// @notice Strict EIP-1271: accepts only 65-byte ECDSA (r,s,v), enforces low-s, and never reverts
    /// @dev The digest provided by coordinator is already an EIP-191 personal_sign digest; do not hash again
    function isValidSignature(bytes32 digest, bytes calldata signature) external view returns (bytes4) {
        if (signature.length != 65) {
            return EIP1271_INVALID;
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        // Parse 65-byte signature directly from calldata to avoid unnecessary memory copy
        // signature layout: r (32) | s (32) | v (1)
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        // Accept v=0/1 by normalizing to 27/28
        if (v < 27) {
            v += 27;
        }
        if (v != 27 && v != 28) {
            return EIP1271_INVALID;
        }

        // Enforce low-s (reject high-s malleability)
        if (uint256(s) > SECP256K1N_HALF) {
            return EIP1271_INVALID;
        }

        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0)) {
            return EIP1271_INVALID;
        }

        return recovered == operator ? EIP1271_MAGICVALUE : EIP1271_INVALID;
    }

    // ==========================
    // ========
    //  User Actions: deposit / withdraw
    // ========
    // ==========================

    /// @notice Deposit BOTCOIN
    /// @dev Immediate: affects current epoch tier/allocation immediately; Cutoff: enters vault and activates next epoch
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert ZeroAmount();
        }

        _checkpointEpoch();

        uint64 cur = _currentEpoch();
        uint64 effective = _effectiveEpochForDeposit(cur);

        if (depositMode == DepositMode.Immediate) {
            // Shares change immediately; settle current epoch credits using previous shares first
            _settleUserEpochCredits(msg.sender, cur);

            _safeTransferFrom(botcoinToken, msg.sender, address(this), amount);

            totalActiveShares += amount;

            uint256 oldShares = _getUserSharesAtEpoch(msg.sender, cur);
            uint256 newShares = oldShares + amount;
            _writeUserSharesCheckpoint(msg.sender, cur, newShares);

            // After share change, update debt to newShares * acc to prevent new deposits from earning historical credits
            userEpochCreditDebtScaled[msg.sender][cur] = newShares * epochAccCreditsPerShare[cur];
        } else {
            // Cutoff: pending shares move into vault and do not affect current active shares
            _safeTransferFrom(botcoinToken, msg.sender, address(vault), amount);

            scheduledActivationShares[effective] += amount;

            uint256 oldSharesAtEffective = _getUserSharesAtEpoch(msg.sender, effective);
            uint256 newSharesAtEffective = oldSharesAtEffective + amount;
            _writeUserSharesCheckpoint(msg.sender, effective, newSharesAtEffective);
        }

        userEpochPrincipal[msg.sender][effective] += amount;

        emit Deposited(msg.sender, amount, cur, effective);
    }

    /// @notice Withdraw BOTCOIN principal (strict lock: cannot withdraw in-epoch; must be withdrawable after epoch end)
    function withdraw(uint256 amount, address to) external nonReentrant {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (to == address(0)) {
            revert ZeroAddress();
        }

        _checkpointEpoch();

        uint64 cur = _currentEpoch();

        uint256 sharesCur = _getUserSharesAtEpoch(msg.sender, cur);
        uint256 lockedCur = userEpochPrincipal[msg.sender][cur];
        if (sharesCur < lockedCur) {
            // Should never happen; indicates mismatch between share checkpoints and principal locks, so fail-closed
            revert();
        }
        uint256 unlockedCur = sharesCur - lockedCur;
        if (amount > unlockedCur) {
            revert WithdrawLocked(cur, cur);
        }

        // Shares are about to decrease; settle current epoch credits with previous shares first
        _settleUserEpochCredits(msg.sender, cur);

        totalActiveShares -= amount;

        uint256 newSharesCur = sharesCur - amount;
        _writeUserSharesCheckpoint(msg.sender, cur, newSharesCur);
        userEpochCreditDebtScaled[msg.sender][cur] = newSharesCur * epochAccCreditsPerShare[cur];

        // Cutoff: if current epoch still has pending principal (written into cur+1 checkpoint), reduce future shares too
        if (depositMode == DepositMode.NextEpochCutoff) {
            uint64 nextEpoch = cur + 1;
            if (userEpochPrincipal[msg.sender][nextEpoch] > 0) {
                uint256 sharesNext = _getUserSharesAtEpoch(msg.sender, nextEpoch);
                _writeUserSharesCheckpoint(msg.sender, nextEpoch, sharesNext - amount);
            }
        }

        _safeTransfer(botcoinToken, to, amount);

        emit Withdrawn(msg.sender, to, amount, cur);
    }

    // ==========================
    // ========
    //  Operator: submit receipt (strict boundary)
    // ========
    // ==========================

    /// @notice Only operator may forward coordinator receipt calldata to mining contract, and Δcredits must be > 0
    function submitReceiptToMining(bytes calldata miningCalldata) external onlyOperator nonReentrant {
        // Explicit checkpoint: ensure epoch-effective deposits are rolled from vault into pool in Cutoff mode
        _checkpointEpoch();

        if (miningCalldata.length < 4) {
            revert InvalidSelector(bytes4(0), receiptSubmitSelector);
        }

        bytes4 selector;
        assembly {
            selector := calldataload(miningCalldata.offset)
        }
        if (selector != receiptSubmitSelector) {
            revert InvalidSelector(selector, receiptSubmitSelector);
        }

        uint64 cur = _currentEpoch();

        if (totalActiveShares == 0) {
            revert NoActiveShares(cur);
        }

        uint64 beforeCredits = mining.credits(cur, address(this));

        (bool ok,) = address(mining).call(miningCalldata);
        if (!ok) {
            revert MiningCallFailed();
        }

        uint64 afterCredits = mining.credits(cur, address(this));
        if (afterCredits <= beforeCredits) {
            revert CreditsDidNotIncrease(cur, beforeCredits, afterCredits);
        }

        uint256 delta = uint256(afterCredits - beforeCredits);
        epochPoolCredits[cur] += delta;

        uint256 acc = epochAccCreditsPerShare[cur] + (delta * ACC_PRECISION) / totalActiveShares;
        epochAccCreditsPerShare[cur] = acc;

        emit ReceiptForwarded(cur, delta, totalActiveShares, epochPoolCredits[cur], acc);
    }

    // ==========================
    // ========
    //  Rewards：claimRewards / claimUser（permissionless）
    // ========
    // ==========================

    /// @notice Permissionless claim from mining for a finished epoch, recording net BOTCOIN after immutable fee
    function claimRewards(uint64 epoch) external nonReentrant {
        _checkpointEpoch();

        uint64 cur = _currentEpoch();
        if (epoch >= cur) {
            revert EpochNotEnded(epoch, cur);
        }
        if (epochRewardsClaimed[epoch]) {
            revert EpochAlreadyClaimed(epoch);
        }

        uint256 beforeBal = botcoinToken.balanceOf(address(this));

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = epoch;
        mining.claim(epochs);

        uint256 afterBal = botcoinToken.balanceOf(address(this));
        uint256 gross = afterBal - beforeBal;
        if (gross == 0) {
            revert NothingToClaim();
        }

        uint256 fee = (gross * feeBps) / BPS_DENOMINATOR;
        uint256 net = gross - fee;

        epochRewardsClaimed[epoch] = true;
        epochBotcoinNet[epoch] = net;

        if (fee != 0) {
            _safeTransfer(botcoinToken, feeRecipient, fee);
        }

        emit EpochRewardsClaimed(epoch, gross, fee, net, feeRecipient);
    }

    /// @notice User claims rewards by epochs in batch (up to maxEpochsPerClaim), without trusting operator
    function claimUser(uint64[] calldata epochs, address to) external nonReentrant {
        if (to == address(0)) {
            revert ZeroAddress();
        }
        if (epochs.length == 0) {
            revert NothingToClaim();
        }
        if (epochs.length > maxEpochsPerClaim) {
            revert TooManyEpochs(epochs.length, maxEpochsPerClaim);
        }

        uint64 prev = 0;
        for (uint256 i = 0; i < epochs.length; i++) {
            uint64 e = epochs[i];
            if (i != 0 && e <= prev) {
                revert EpochsNotStrictlyIncreasing();
            }
            prev = e;

            if (!epochRewardsClaimed[e]) {
                revert EpochNotClaimed(e);
            }

            _settleUserEpochCredits(msg.sender, e);

            uint256 userScaled = userEpochCreditsScaled[msg.sender][e];
            if (userScaled == 0) {
                continue;
            }

            uint256 poolCredits = epochPoolCredits[e];
            if (poolCredits == 0) {
                // Rewards claimed without pool credits is abnormal by design, so fail-closed
                revert NothingToClaim();
            }

            uint256 denom = poolCredits * ACC_PRECISION;
            uint256 payout = (userScaled * epochBotcoinNet[e]) / denom;

            userEpochCreditsScaled[msg.sender][e] = 0;
            epochBotcoinPaid[e] += payout;

            if (payout != 0) {
                _safeTransfer(botcoinToken, to, payout);
            }

            emit UserRewardsClaimed(msg.sender, to, e, payout);
        }
    }

    // ==================
    // ========
    //  Checkpoint / Views
    // ========
    // ==================

    /// @notice Permissionless Cutoff rollover trigger (no-op in Immediate mode)
    function checkpointEpoch() external nonReentrant {
        _checkpointEpoch();
    }

    function getEpochState(uint64 epoch)
        external
        view
        returns (uint256 accCreditsPerShare, uint256 poolCredits, uint256 botcoinNet, uint256 botcoinPaid, bool claimed)
    {
        return (
            epochAccCreditsPerShare[epoch],
            epochPoolCredits[epoch],
            epochBotcoinNet[epoch],
            epochBotcoinPaid[epoch],
            epochRewardsClaimed[epoch]
        );
    }

    function getUserEpochState(address user, uint64 epoch)
        external
        view
        returns (uint256 shares, uint256 creditDebtScaled, uint256 creditsScaled)
    {
        return (
            _getUserSharesAtEpoch(user, epoch),
            userEpochCreditDebtScaled[user][epoch],
            userEpochCreditsScaled[user][epoch]
        );
    }

    function getUserPrincipalState(address user)
        external
        view
        returns (uint256 sharesCur, uint256 lockedCur, uint256 unlockedCur, uint256 sharesNext)
    {
        uint64 cur = mining.currentEpoch();
        sharesCur = _getUserSharesAtEpoch(user, cur);
        lockedCur = userEpochPrincipal[user][cur];
        unlockedCur = sharesCur >= lockedCur ? (sharesCur - lockedCur) : 0;
        sharesNext = _getUserSharesAtEpoch(user, cur + 1);
    }

    function userSharesAtEpoch(address user, uint64 epoch) external view returns (uint256) {
        return _getUserSharesAtEpoch(user, epoch);
    }

    // ==================
    // ========
    //  Internal Helpers: epoch / checkpoint / settlement / checkpoints
    // ========
    // ==================

    function _currentEpoch() internal view returns (uint64) {
        return mining.currentEpoch();
    }

    function _effectiveEpochForDeposit(uint64 currentEpoch_) internal view returns (uint64) {
        if (depositMode == DepositMode.Immediate) {
            return currentEpoch_;
        }
        unchecked {
            return currentEpoch_ + 1;
        }
    }

    /// @dev Core Cutoff behavior: roll pending shares from vault into pool at epoch boundaries
    function _checkpointEpoch() internal {
        if (depositMode != DepositMode.NextEpochCutoff) {
            return;
        }

        uint64 cur = mining.currentEpoch();
        uint64 last = lastCheckpointEpoch;
        if (cur <= last) {
            return;
        }

        // Activate one epoch at a time (allows multi-epoch catch-up; may be expensive in extremes but keeps semantics exact)
        for (uint64 e = last + 1; e <= cur; e++) {
            uint256 activate = scheduledActivationShares[e];
            if (activate != 0) {
                scheduledActivationShares[e] = 0;
                totalActiveShares += activate;
                vault.transferToPool(activate);
                emit RolloverExecuted(e, activate);
            }
        }

        lastCheckpointEpoch = cur;
    }

    /// @dev Settle user credits for an epoch via index-debt accounting
    function _settleUserEpochCredits(address user, uint64 epoch) internal {
        uint256 shares = _getUserSharesAtEpoch(user, epoch);
        uint256 acc = epochAccCreditsPerShare[epoch];

        uint256 accumulated = shares * acc;
        uint256 debt = userEpochCreditDebtScaled[user][epoch];

        if (accumulated < debt) {
            // Should never happen if share-write ordering is correct; fail-closed to avoid underflow
            revert();
        }

        uint256 pending = accumulated - debt;
        if (pending != 0) {
            userEpochCreditsScaled[user][epoch] += pending;
        }

        userEpochCreditDebtScaled[user][epoch] = accumulated;
    }

    /// @dev Binary search: returns user effective shares at target epoch (0 when no checkpoint exists)
    function _getUserSharesAtEpoch(address user, uint64 epoch) internal view returns (uint256) {
        ShareCheckpoint[] storage cps = _shareCheckpoints[user];
        uint256 n = cps.length;
        if (n == 0) {
            return 0;
        }

        // If target epoch is at/after the last checkpoint, return last value directly
        if (cps[n - 1].epoch <= epoch) {
            return cps[n - 1].shares;
        }

        // If target epoch is before the first checkpoint, return 0
        if (cps[0].epoch > epoch) {
            return 0;
        }

        // Standard binary search: find the last cps[i].epoch <= epoch
        uint256 lo = 0;
        uint256 hi = n - 1;
        while (lo + 1 < hi) {
            uint256 mid = (lo + hi) / 2;
            if (cps[mid].epoch <= epoch) {
                lo = mid;
            } else {
                hi = mid;
            }
        }
        return cps[lo].shares;
    }

    /// @dev Write share checkpoint, including insertion right before tail (for Cutoff writing cur+1 then cur)
    function _writeUserSharesCheckpoint(address user, uint64 epoch, uint256 shares) internal {
        ShareCheckpoint[] storage cps = _shareCheckpoints[user];
        uint256 n = cps.length;

        if (n == 0) {
            cps.push(ShareCheckpoint({epoch: epoch, shares: shares}));
            return;
        }

        uint64 lastEpoch = cps[n - 1].epoch;
        if (epoch > lastEpoch) {
            cps.push(ShareCheckpoint({epoch: epoch, shares: shares}));
            return;
        }
        if (epoch == lastEpoch) {
            cps[n - 1].shares = shares;
            return;
        }

        // epoch < lastEpoch is only allowed when last checkpoint is cur+1 and we are now writing cur
        if (n == 1) {
            // Insert at head (push a copy of last to tail, then overwrite index 0)
            ShareCheckpoint memory last = cps[0];
            cps.push(last);
            cps[0] = ShareCheckpoint({epoch: epoch, shares: shares});
            return;
        }

        uint64 secondLastEpoch = cps[n - 2].epoch;
        if (epoch == secondLastEpoch) {
            cps[n - 2].shares = shares;
            return;
        }
        if (epoch < secondLastEpoch) {
            revert CheckpointOutOfOrder(epoch, lastEpoch, secondLastEpoch);
        }

        // Insert between secondLast and last: push(last) then overwrite cps[n-1]
        ShareCheckpoint memory last2 = cps[n - 1];
        cps.push(last2);
        cps[n - 1] = ShareCheckpoint({epoch: epoch, shares: shares});
    }

    function _safeTransfer(IERC20Minimal token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert();
        }
    }

    function _safeTransferFrom(IERC20Minimal token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert();
        }
    }
}
