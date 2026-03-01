// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MockMiningV2} from "../mocks/MockMiningV2.sol";
import {SharedMiningPoolV2Base} from "./SharedMiningPoolV2Base.t.sol";

/// @notice This test verifies regular and bonus reward accounting and user claim payouts.
contract ClaimFlowV2Test is SharedMiningPoolV2Base {
    /// @notice This setup provisions two users and activates/stakes shares for epoch-2 mining.
    function setUp() public override {
        super.setUp();

        vm.prank(user1);
        pool.deposit(100e18);

        vm.prank(user2);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();

        mining.setSubmitCreditDelta(address(pool), 2);

        bytes memory miningCalldata = abi.encodeWithSelector(MockMiningV2.submitReceipt.selector, bytes("receipt"));
        vm.prank(operator);
        pool.submitReceiptToMining(miningCalldata);
    }

    /// @notice This test verifies regular and bonus claims update user payouts and fee accounting.
    function testRegularAndBonusClaimFlow() external {
        mining.fundEpochReward(2, 1_000e18);

        bonus.setBonusEpoch(2, true);
        bonus.setBonusClaimsOpen(2, true);
        bonus.fundBonusReward(2, 200e18);

        _rollToEpoch(3);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        pool.claimRewards(epochs);
        pool.claimBonusRewards(epochs);

        // fee = 5% of (1000 + 200) = 60
        assertEq(botcoin.balanceOf(feeRecipient), 60e18);
        // net = 1140
        assertEq(pool.epochTotalNetReward(2), 1_140e18);

        vm.prank(user1);
        pool.claimUser(epochs, user1);

        vm.prank(user2);
        pool.claimUser(epochs, user2);

        // two users with equal shares split net reward evenly
        assertEq(botcoin.balanceOf(user1), 200_000_000e18 - 100e18 + 570e18);
        assertEq(botcoin.balanceOf(user2), 200_000_000e18 - 100e18 + 570e18);
    }

    /// @notice This test verifies user can claim delayed bonus increment in second call.
    function testUserCanClaimDelayedBonusIncrement() external {
        mining.fundEpochReward(2, 1_000e18);

        _rollToEpoch(3);

        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 2;

        pool.claimRewards(epochs);

        vm.prank(user1);
        pool.claimUser(epochs, user1);

        uint256 afterRegular = botcoin.balanceOf(user1);

        bonus.setBonusEpoch(2, true);
        bonus.setBonusClaimsOpen(2, true);
        bonus.fundBonusReward(2, 100e18);

        pool.claimBonusRewards(epochs);

        vm.prank(user1);
        pool.claimUser(epochs, user1);

        assertGt(botcoin.balanceOf(user1), afterRegular);
    }
}
