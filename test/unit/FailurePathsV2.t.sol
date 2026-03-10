// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {SharedMiningPoolV2Base} from "./SharedMiningPoolV2Base.t.sol";

import {MockBonusEpoch} from "../mocks/MockBonusEpoch.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/// @notice This unit test suite validates common `deposit` failure paths.
contract DepositFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies deposit rejects zero amount.
    function testDepositRevertsOnZeroAmount() external {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.ZeroAmount.selector));
        pool.deposit(0);
        vm.stopPrank();
    }

    /// @notice This test verifies deposits are blocked in WithdrawnIdle phase.
    function testDepositBlockedInWithdrawnIdle() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();

        pool.unstakeAtEpochEnd();
        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);
        pool.completeWithdraw();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.WithdrawnIdle));

        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.DepositClosed.selector, SharedMiningPoolV2.PoolPhase.WithdrawnIdle
            )
        );
        pool.deposit(1e18);
        vm.stopPrank();
    }
}

/// @notice This unit test suite validates `claimMyShare` failure paths.
contract ClaimMyShareFailurePathsV2Test is SharedMiningPoolV2Base {
    function _enterWithdrawnIdleWithDeposit(uint256 amount) internal {
        vm.prank(user1);
        pool.deposit(amount);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();

        pool.unstakeAtEpochEnd();
        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);
        pool.completeWithdraw();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.WithdrawnIdle));
    }

    /// @notice This test verifies claimMyShare is rejected in Cooldown phase.
    function testClaimMyShareRejectedInCooldown() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();
        pool.unstakeAtEpochEnd();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.Cooldown));

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.InvalidPhase.selector,
                SharedMiningPoolV2.PoolPhase.WithdrawnIdle,
                SharedMiningPoolV2.PoolPhase.Cooldown
            )
        );
        pool.claimMyShare(1e18, user1);
        vm.stopPrank();
    }

    /// @notice This test verifies claimMyShare rejects zero amount.
    function testClaimMyShareRevertsOnZeroAmount() external {
        _enterWithdrawnIdleWithDeposit(100e18);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.ZeroAmount.selector));
        pool.claimMyShare(0, user1);
        vm.stopPrank();
    }

    /// @notice This test verifies claimMyShare rejects zero receiver.
    function testClaimMyShareRevertsOnZeroAddress() external {
        _enterWithdrawnIdleWithDeposit(100e18);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.ZeroAddress.selector));
        pool.claimMyShare(1e18, address(0));
        vm.stopPrank();
    }

    /// @notice This test verifies claimMyShare rejects requests exceeding available principal.
    function testClaimMyShareRevertsOnInsufficientPrincipal() external {
        _enterWithdrawnIdleWithDeposit(100e18);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.InsufficientPrincipal.selector, 200e18, 100e18));
        pool.claimMyShare(200e18, user1);
        vm.stopPrank();
    }
}

/// @notice This unit test suite validates `unstakeAtEpochEnd` failure paths.
contract UnstakeFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies unstake reverts when nothing is staked.
    function testUnstakeRevertsWhenNoStake() external {
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.RestakeAmountZero.selector));
        pool.unstakeAtEpochEnd();
    }

    /// @notice This test verifies calling unstake twice is rejected by phase gating.
    function testUnstakeRejectedInCooldownPhase() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();
        pool.unstakeAtEpochEnd();

        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.InvalidPhase.selector,
                SharedMiningPoolV2.PoolPhase.ActiveStaked,
                SharedMiningPoolV2.PoolPhase.Cooldown
            )
        );
        pool.unstakeAtEpochEnd();
    }

    /// @notice This test verifies epoch boundary gating after a restake within the same epoch.
    function testUnstakeRevertsBeforeEpochBoundaryAfterRestake() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();

        pool.unstakeAtEpochEnd();
        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);
        pool.completeWithdraw();
        pool.restake();

        uint64 current = mining.currentEpoch();
        uint64 minEpoch = pool.unstakeAvailableAtEpoch();

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.EpochBoundaryNotReached.selector, current, minEpoch));
        pool.unstakeAtEpochEnd();
    }
}

/// @notice This unit test suite validates `completeWithdraw` failure paths.
contract CompleteWithdrawFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies completeWithdraw is rejected outside Cooldown phase.
    function testCompleteWithdrawRejectedInActivePhase() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.InvalidPhase.selector,
                SharedMiningPoolV2.PoolPhase.Cooldown,
                SharedMiningPoolV2.PoolPhase.ActiveStaked
            )
        );
        pool.completeWithdraw();
    }

    /// @notice This test verifies completeWithdraw rejects calls before cooldown completion.
    function testCompleteWithdrawRevertsBeforeCooldownFinished() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();
        pool.unstakeAtEpochEnd();

        uint64 readyAt = mining.withdrawableAt(address(pool));
        uint64 nowTs = uint64(block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.CooldownNotFinished.selector, readyAt, nowTs));
        pool.completeWithdraw();
    }
}

/// @notice This unit test suite validates `stakeAvailablePrincipal` failure paths.
contract StakeAvailablePrincipalFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies stakeAvailablePrincipal is rejected outside ActiveStaked phase.
    function testStakeAvailablePrincipalRejectedInWithdrawnIdle() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();
        pool.unstakeAtEpochEnd();
        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);
        pool.completeWithdraw();

        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.InvalidPhase.selector,
                SharedMiningPoolV2.PoolPhase.ActiveStaked,
                SharedMiningPoolV2.PoolPhase.WithdrawnIdle
            )
        );
        pool.stakeAvailablePrincipal();
    }

    /// @notice This test verifies stakeAvailablePrincipal reverts when delta to stake is zero.
    function testStakeAvailablePrincipalRevertsWhenDeltaIsZero() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.RestakeAmountZero.selector));
        pool.stakeAvailablePrincipal();
    }

    /// @notice This test verifies stakeAvailablePrincipal reverts when pool token balance is insufficient.
    function testStakeAvailablePrincipalRevertsOnInsufficientBalance() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);

        // Simulate unexpected loss of pool custody token balance (e.g. token anomaly).
        vm.prank(address(pool));
        botcoin.transfer(user1, 100e18);

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.RestakeInsufficientBalance.selector, 100e18, 0));
        pool.stakeAvailablePrincipal();
    }
}

/// @notice This unit test suite validates `restake` failure paths.
contract RestakeFailurePathsV2Test is SharedMiningPoolV2Base {
    function _enterWithdrawnIdleWithDeposit(uint256 amount) internal {
        vm.prank(user1);
        pool.deposit(amount);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();
        pool.unstakeAtEpochEnd();
        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);
        pool.completeWithdraw();
    }

    /// @notice This test verifies restake is rejected outside WithdrawnIdle phase.
    function testRestakeRejectedInActivePhase() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.InvalidPhase.selector,
                SharedMiningPoolV2.PoolPhase.WithdrawnIdle,
                SharedMiningPoolV2.PoolPhase.ActiveStaked
            )
        );
        pool.restake();
    }

    /// @notice This test verifies restake reverts when no principal liability exists.
    function testRestakeRevertsWhenNoPrincipalLiability() external {
        _enterWithdrawnIdleWithDeposit(100e18);

        vm.prank(user1);
        pool.claimMyShare(100e18, user1);

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.RestakeAmountZero.selector));
        pool.restake();
    }

    /// @notice This test verifies restake reverts when pool token balance is insufficient.
    function testRestakeRevertsOnInsufficientBalance() external {
        _enterWithdrawnIdleWithDeposit(100e18);

        vm.prank(address(pool));
        botcoin.transfer(user1, 100e18);

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.RestakeInsufficientBalance.selector, 100e18, 0));
        pool.restake();
    }
}

/// @notice This unit test suite validates `triggerClaim` failure paths.
contract TriggerClaimFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies triggerClaim rejects empty epoch list.
    function testTriggerClaimRevertsOnEmptyEpochList() external {
        uint64[] memory epochs = new uint64[](0);
        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.InvalidEpochList.selector, uint256(0), pool.maxEpochsPerClaim())
        );
        pool.triggerClaim(epochs);
    }

    /// @notice This test verifies triggerClaim rejects non-increasing epoch list.
    function testTriggerClaimRevertsOnNonIncreasingEpochList() external {
        uint64[] memory epochs = new uint64[](2);
        epochs[0] = 2;
        epochs[1] = 2;

        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.InvalidEpochList.selector, uint256(2), pool.maxEpochsPerClaim())
        );
        pool.triggerClaim(epochs);
    }

    /// @notice This test verifies triggerClaim rejects epochs that have not ended.
    function testTriggerClaimRevertsWhenEpochNotEnded() external {
        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 1;

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.EpochNotEnded.selector, uint64(1), uint64(1)));
        pool.triggerClaim(epochs);
    }

    /// @notice This test verifies triggerClaim rejects repeated claims for the same epoch.
    function testTriggerClaimRevertsWhenAlreadyClaimed() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakeAvailablePrincipal();

        mining.fundEpochReward(2, 1_000e18);
        _rollToEpoch(3);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        pool.triggerClaim(epochs);

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.RegularAlreadyClaimed.selector, uint64(2)));
        pool.triggerClaim(epochs);
    }

    /// @notice This test verifies triggerClaim reverts if no shares exist for the target epoch.
    function testTriggerClaimRevertsWhenNoSharesForEpoch() external {
        // No deposits => total shares at epoch-1 is zero.
        mining.fundEpochReward(1, 1_000e18);
        _rollToEpoch(2);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 1;

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.NoSharesForEpoch.selector, uint64(1)));
        pool.triggerClaim(epochs);
    }
}

/// @notice This unit test suite validates `triggerBonusClaim` failure paths.
contract TriggerBonusClaimFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies triggerBonusClaim rejects empty epoch list.
    function testTriggerBonusClaimRevertsOnEmptyEpochList() external {
        uint64[] memory epochs = new uint64[](0);
        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.InvalidEpochList.selector, uint256(0), pool.maxEpochsPerClaim())
        );
        pool.triggerBonusClaim(epochs);
    }

    /// @notice This test verifies triggerBonusClaim rejects non-bonus epochs.
    function testTriggerBonusClaimRevertsWhenNotBonusEpoch() external {
        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.NotBonusEpoch.selector, uint64(2)));
        pool.triggerBonusClaim(epochs);
    }

    /// @notice This test verifies triggerBonusClaim rejects epochs when bonus claims are not open.
    function testTriggerBonusClaimRevertsWhenNotOpen() external {
        bonus.setBonusEpoch(2, true);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.BonusNotOpen.selector, uint64(2)));
        pool.triggerBonusClaim(epochs);
    }

    /// @notice This test verifies triggerBonusClaim rejects repeated claims for the same epoch.
    function testTriggerBonusClaimRevertsWhenAlreadyClaimed() external {
        vm.prank(user1);
        pool.deposit(100e18);
        _rollToEpoch(2);

        bonus.setBonusEpoch(2, true);
        bonus.setBonusClaimsOpen(2, true);
        bonus.fundBonusReward(2, 200e18);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        pool.triggerBonusClaim(epochs);

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.BonusAlreadyClaimed.selector, uint64(2)));
        pool.triggerBonusClaim(epochs);
    }
}

/// @notice This unit test suite validates `claimMyRewards` failure paths.
contract ClaimMyRewardsFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies claimMyRewards rejects zero receiver.
    function testClaimMyRewardsRevertsOnZeroReceiver() external {
        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 1;

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.ZeroAddress.selector));
        pool.claimMyRewards(epochs, address(0));
    }

    /// @notice This test verifies claimMyRewards rejects empty epoch list.
    function testClaimMyRewardsRevertsOnEmptyEpochList() external {
        uint64[] memory epochs = new uint64[](0);

        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.InvalidEpochList.selector, uint256(0), pool.maxEpochsPerClaim())
        );
        vm.prank(user1);
        pool.claimMyRewards(epochs, user1);
    }

    /// @notice This test verifies claimMyRewards reverts when user has nothing claimable.
    function testClaimMyRewardsRevertsWhenNothingToClaim() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        _rollToEpoch(3);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.NothingToClaim.selector));
        pool.claimMyRewards(epochs, user1);
        vm.stopPrank();
    }
}

/// @notice This unit test suite validates EIP-1271 invalid `v` behavior.
contract EIP1271FailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies signatures with invalid `v` are rejected.
    function testIsValidSignatureRejectsInvalidV() external view {
        bytes32 digest = keccak256("invalid-v");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorPrivateKey, digest);
        assertTrue(v == 27 || v == 28);

        uint8 invalidV = 29;
        bytes memory signature = abi.encodePacked(r, s, invalidV);

        bytes4 result = pool.isValidSignature(digest, signature);
        assertEq(result, pool.EIP1271_INVALID());
    }
}

/// @notice This mining stub reverts on receipt submission to validate `MiningCallFailed`.
contract RevertingMiningV2 {
    MockERC20 public immutable botcoin;

    uint64 public currentEpoch;

    constructor(address botcoinToken_) {
        botcoin = MockERC20(botcoinToken_);
        currentEpoch = 1;
    }

    function botcoinToken() external view returns (address) {
        return address(botcoin);
    }

    function setEpoch(uint64 epoch) external {
        currentEpoch = epoch;
    }

    function credits(uint64, address) external pure returns (uint64) {
        return 0;
    }

    function claim(uint64[] calldata) external pure {}

    function stake(uint256) external pure {}

    function unstake() external pure {}

    function withdraw() external pure {}

    function withdrawableAt(address) external pure returns (uint64) {
        return 0;
    }

    function stakedAmount(address) external pure returns (uint256) {
        return 0;
    }

    function submitReceipt(bytes calldata) external pure {
        revert("REVERTING_MINING");
    }
}

/// @notice This unit test verifies submitToMining surfaces a failed low-level call as `MiningCallFailed`.
contract SubmitToMiningCallFailedFailurePathsV2Test is Test {
    function testSubmitToMiningRevertsOnMiningCallFailed() external {
        address operator = makeAddr("operator");
        address feeRecipient = makeAddr("feeRecipient");
        address depositor = makeAddr("depositor");

        MockERC20 botcoin = new MockERC20("BOTCOIN", "BOT", 18);
        RevertingMiningV2 mining = new RevertingMiningV2(address(botcoin));
        MockBonusEpoch bonus = new MockBonusEpoch(address(botcoin));
        bonus.setMining(address(mining));

        SharedMiningPoolV2 pool = new SharedMiningPoolV2({
            mining_: address(mining),
            bonusEpoch_: address(bonus),
            operator_: operator,
            feeRecipient_: feeRecipient,
            feeBps_: 500,
            receiptSubmitSelector_: RevertingMiningV2.submitReceipt.selector,
            maxEpochsPerClaim_: 50
        });

        botcoin.mint(depositor, 100e18);

        vm.startPrank(depositor);
        botcoin.approve(address(pool), type(uint256).max);
        pool.deposit(100e18);
        vm.stopPrank();

        mining.setEpoch(2);
        pool.processEpochCheckpoint();

        bytes memory miningCalldata = abi.encodeWithSelector(RevertingMiningV2.submitReceipt.selector, bytes("r"));

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.MiningCallFailed.selector));
        pool.submitToMining(miningCalldata);
    }
}
