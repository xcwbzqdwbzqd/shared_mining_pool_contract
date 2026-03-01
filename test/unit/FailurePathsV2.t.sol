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
        pool.stakePrincipal();

        pool.unstakeAtEpochEnd();
        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);
        pool.finalizeWithdraw();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.WithdrawnIdle));

        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.DepositClosed.selector, SharedMiningPoolV2.PoolPhase.WithdrawnIdle)
        );
        pool.deposit(1e18);
        vm.stopPrank();
    }
}

/// @notice This unit test suite validates `withdrawPrincipal` failure paths.
contract WithdrawPrincipalFailurePathsV2Test is SharedMiningPoolV2Base {
    function _enterWithdrawnIdleWithDeposit(uint256 amount) internal {
        vm.prank(user1);
        pool.deposit(amount);

        _rollToEpoch(2);
        pool.stakePrincipal();

        pool.unstakeAtEpochEnd();
        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);
        pool.finalizeWithdraw();

        assertEq(uint256(pool.phase()), uint256(SharedMiningPoolV2.PoolPhase.WithdrawnIdle));
    }

    /// @notice This test verifies withdrawPrincipal is rejected in Cooldown phase.
    function testWithdrawPrincipalRejectedInCooldown() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();
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
        pool.withdrawPrincipal(1e18, user1);
        vm.stopPrank();
    }

    /// @notice This test verifies withdrawPrincipal rejects zero amount.
    function testWithdrawPrincipalRevertsOnZeroAmount() external {
        _enterWithdrawnIdleWithDeposit(100e18);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.ZeroAmount.selector));
        pool.withdrawPrincipal(0, user1);
        vm.stopPrank();
    }

    /// @notice This test verifies withdrawPrincipal rejects zero receiver.
    function testWithdrawPrincipalRevertsOnZeroAddress() external {
        _enterWithdrawnIdleWithDeposit(100e18);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.ZeroAddress.selector));
        pool.withdrawPrincipal(1e18, address(0));
        vm.stopPrank();
    }

    /// @notice This test verifies withdrawPrincipal rejects requests exceeding available principal.
    function testWithdrawPrincipalRevertsOnInsufficientPrincipal() external {
        _enterWithdrawnIdleWithDeposit(100e18);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.InsufficientPrincipal.selector, 200e18, 100e18));
        pool.withdrawPrincipal(200e18, user1);
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
        pool.stakePrincipal();
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
        pool.stakePrincipal();

        pool.unstakeAtEpochEnd();
        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);
        pool.finalizeWithdraw();
        pool.restake();

        uint64 current = mining.currentEpoch();
        uint64 minEpoch = pool.unstakeAvailableAtEpoch();

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.EpochBoundaryNotReached.selector, current, minEpoch));
        pool.unstakeAtEpochEnd();
    }
}

/// @notice This unit test suite validates `finalizeWithdraw` failure paths.
contract FinalizeWithdrawFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies finalizeWithdraw is rejected outside Cooldown phase.
    function testFinalizeWithdrawRejectedInActivePhase() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.InvalidPhase.selector,
                SharedMiningPoolV2.PoolPhase.Cooldown,
                SharedMiningPoolV2.PoolPhase.ActiveStaked
            )
        );
        pool.finalizeWithdraw();
    }

    /// @notice This test verifies finalizeWithdraw rejects calls before cooldown completion.
    function testFinalizeWithdrawRevertsBeforeCooldownFinished() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();
        pool.unstakeAtEpochEnd();

        uint64 readyAt = mining.withdrawableAt(address(pool));
        uint64 nowTs = uint64(block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.CooldownNotFinished.selector, readyAt, nowTs));
        pool.finalizeWithdraw();
    }
}

/// @notice This unit test suite validates `stakePrincipal` failure paths.
contract StakePrincipalFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies stakePrincipal is rejected outside ActiveStaked phase.
    function testStakePrincipalRejectedInWithdrawnIdle() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();
        pool.unstakeAtEpochEnd();
        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);
        pool.finalizeWithdraw();

        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolV2.InvalidPhase.selector,
                SharedMiningPoolV2.PoolPhase.ActiveStaked,
                SharedMiningPoolV2.PoolPhase.WithdrawnIdle
            )
        );
        pool.stakePrincipal();
    }

    /// @notice This test verifies stakePrincipal reverts when delta to stake is zero.
    function testStakePrincipalRevertsWhenDeltaIsZero() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.RestakeAmountZero.selector));
        pool.stakePrincipal();
    }

    /// @notice This test verifies stakePrincipal reverts when pool token balance is insufficient.
    function testStakePrincipalRevertsOnInsufficientBalance() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);

        // Simulate unexpected loss of pool custody token balance (e.g. token anomaly).
        vm.prank(address(pool));
        botcoin.transfer(user1, 100e18);

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.RestakeInsufficientBalance.selector, 100e18, 0));
        pool.stakePrincipal();
    }
}

/// @notice This unit test suite validates `restake` failure paths.
contract RestakeFailurePathsV2Test is SharedMiningPoolV2Base {
    function _enterWithdrawnIdleWithDeposit(uint256 amount) internal {
        vm.prank(user1);
        pool.deposit(amount);

        _rollToEpoch(2);
        pool.stakePrincipal();
        pool.unstakeAtEpochEnd();
        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);
        pool.finalizeWithdraw();
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
        pool.withdrawPrincipal(100e18, user1);

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

/// @notice This unit test suite validates `claimRewards` failure paths.
contract ClaimRewardsFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies claimRewards rejects empty epoch list.
    function testClaimRewardsRevertsOnEmptyEpochList() external {
        uint64[] memory epochs = new uint64[](0);
        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.InvalidEpochList.selector, uint256(0), pool.maxEpochsPerClaim())
        );
        pool.claimRewards(epochs);
    }

    /// @notice This test verifies claimRewards rejects non-increasing epoch list.
    function testClaimRewardsRevertsOnNonIncreasingEpochList() external {
        uint64[] memory epochs = new uint64[](2);
        epochs[0] = 2;
        epochs[1] = 2;

        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.InvalidEpochList.selector, uint256(2), pool.maxEpochsPerClaim())
        );
        pool.claimRewards(epochs);
    }

    /// @notice This test verifies claimRewards rejects epochs that have not ended.
    function testClaimRewardsRevertsWhenEpochNotEnded() external {
        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 1;

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.EpochNotEnded.selector, uint64(1), uint64(1)));
        pool.claimRewards(epochs);
    }

    /// @notice This test verifies claimRewards rejects repeated claims for the same epoch.
    function testClaimRewardsRevertsWhenAlreadyClaimed() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();

        mining.fundEpochReward(2, 1_000e18);
        _rollToEpoch(3);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        pool.claimRewards(epochs);

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.RegularAlreadyClaimed.selector, uint64(2)));
        pool.claimRewards(epochs);
    }

    /// @notice This test verifies claimRewards reverts if no shares exist for the target epoch.
    function testClaimRewardsRevertsWhenNoSharesForEpoch() external {
        // No deposits => total shares at epoch-1 is zero.
        mining.fundEpochReward(1, 1_000e18);
        _rollToEpoch(2);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 1;

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.NoSharesForEpoch.selector, uint64(1)));
        pool.claimRewards(epochs);
    }
}

/// @notice This unit test suite validates `claimBonusRewards` failure paths.
contract ClaimBonusRewardsFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies claimBonusRewards rejects empty epoch list.
    function testClaimBonusRewardsRevertsOnEmptyEpochList() external {
        uint64[] memory epochs = new uint64[](0);
        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.InvalidEpochList.selector, uint256(0), pool.maxEpochsPerClaim())
        );
        pool.claimBonusRewards(epochs);
    }

    /// @notice This test verifies claimBonusRewards rejects non-bonus epochs.
    function testClaimBonusRewardsRevertsWhenNotBonusEpoch() external {
        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.NotBonusEpoch.selector, uint64(2)));
        pool.claimBonusRewards(epochs);
    }

    /// @notice This test verifies claimBonusRewards rejects epochs when bonus claims are not open.
    function testClaimBonusRewardsRevertsWhenNotOpen() external {
        bonus.setBonusEpoch(2, true);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.BonusNotOpen.selector, uint64(2)));
        pool.claimBonusRewards(epochs);
    }

    /// @notice This test verifies claimBonusRewards rejects repeated claims for the same epoch.
    function testClaimBonusRewardsRevertsWhenAlreadyClaimed() external {
        vm.prank(user1);
        pool.deposit(100e18);
        _rollToEpoch(2);

        bonus.setBonusEpoch(2, true);
        bonus.setBonusClaimsOpen(2, true);
        bonus.fundBonusReward(2, 200e18);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        pool.claimBonusRewards(epochs);

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.BonusAlreadyClaimed.selector, uint64(2)));
        pool.claimBonusRewards(epochs);
    }
}

/// @notice This unit test suite validates `claimUser` failure paths.
contract ClaimUserFailurePathsV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies claimUser rejects zero receiver.
    function testClaimUserRevertsOnZeroReceiver() external {
        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 1;

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.ZeroAddress.selector));
        pool.claimUser(epochs, address(0));
    }

    /// @notice This test verifies claimUser rejects empty epoch list.
    function testClaimUserRevertsOnEmptyEpochList() external {
        uint64[] memory epochs = new uint64[](0);

        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.InvalidEpochList.selector, uint256(0), pool.maxEpochsPerClaim())
        );
        vm.prank(user1);
        pool.claimUser(epochs, user1);
    }

    /// @notice This test verifies claimUser reverts when user has nothing claimable.
    function testClaimUserRevertsWhenNothingToClaim() external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        _rollToEpoch(3);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.NothingToClaim.selector));
        pool.claimUser(epochs, user1);
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

    function claim(uint64[] calldata) external pure { }

    function stake(uint256) external pure { }

    function unstake() external pure { }

    function withdraw() external pure { }

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

/// @notice This unit test verifies submitReceiptToMining surfaces a failed low-level call as `MiningCallFailed`.
contract SubmitReceiptMiningCallFailedFailurePathsV2Test is Test {
    function testSubmitReceiptToMiningRevertsOnMiningCallFailed() external {
        address operator = makeAddr("operator");
        address feeRecipient = makeAddr("feeRecipient");
        address depositor = makeAddr("depositor");

        MockERC20 botcoin = new MockERC20("BOTCOIN", "BOT", 18);
        RevertingMiningV2 mining = new RevertingMiningV2(address(botcoin));
        MockBonusEpoch bonus = new MockBonusEpoch(address(botcoin));

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
        pool.checkpointEpoch();

        bytes memory miningCalldata = abi.encodeWithSelector(RevertingMiningV2.submitReceipt.selector, bytes("r"));

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolV2.MiningCallFailed.selector));
        pool.submitReceiptToMining(miningCalldata);
    }
}
