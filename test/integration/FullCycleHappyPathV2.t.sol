// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MockMiningV2} from "../mocks/MockMiningV2.sol";
import {SharedMiningPoolV2Base} from "../unit/SharedMiningPoolV2Base.t.sol";

/// @notice This integration test covers end-to-end flow across deposit, stake, submit, claims, unstake, finalize, and restake.
contract FullCycleHappyPathV2Test is SharedMiningPoolV2Base {
    /// @notice This test executes one full cycle with regular and bonus reward processing.
    function testFullCycle() external {
        vm.prank(user1);
        pool.deposit(300e18);

        vm.prank(user2);
        pool.deposit(300e18);

        _rollToEpoch(2);
        pool.stakePrincipal();

        mining.setSubmitCreditDelta(address(pool), 3);
        bytes memory miningCalldata = abi.encodeWithSelector(MockMiningV2.submitReceipt.selector, bytes("receipt"));

        vm.prank(operator);
        pool.submitReceiptToMining(miningCalldata);

        mining.fundEpochReward(2, 900e18);
        bonus.setBonusEpoch(2, true);
        bonus.setBonusClaimsOpen(2, true);
        bonus.fundBonusReward(2, 300e18);

        _rollToEpoch(3);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        pool.claimRewards(epochs);
        pool.claimBonusRewards(epochs);

        vm.prank(user1);
        pool.claimUser(epochs, user1);

        vm.prank(user2);
        pool.claimUser(epochs, user2);

        pool.unstakeAtEpochEnd();
        uint64 readyAt = mining.withdrawableAt(address(pool));
        vm.warp(readyAt);
        pool.finalizeWithdraw();
        pool.restake();

        assertEq(pool.epochCredits(2), 3);
    }
}
