// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {SharedMiningPoolContract} from "../../src/SharedMiningPoolContract.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockMining} from "../mocks/MockMining.sol";

/// @notice Fuzz and boundary tests for claimUser input constraints:
/// - upper bound for epochs array length
/// - strict increasing order requirement
/// - `to` cannot be zero address
contract ClaimUserEpochConstraintsTest is Test {
    SharedMiningPoolContract internal pool;

    function setUp() external {
        MockERC20 botcoin = new MockERC20("Botcoin", "BOT", 18);
        MockMining mining = new MockMining(address(botcoin));

        pool = new SharedMiningPoolContract({
            miningContract_: address(mining),
            operator_: makeAddr("operator"),
            feeRecipient_: makeAddr("feeRecipient"),
            feeBps_: 500,
            depositMode_: SharedMiningPoolContract.DepositMode.Immediate,
            receiptSubmitSelector_: MockMining.submitReceipt.selector,
            maxEpochsPerClaim_: 3
        });

        // Pre-mark epoch=1 as claimed so later cases can reach strict-increasing checks
        mining.fundEpochReward(1, 1e18);
        mining.setEpoch(2);
        pool.claimRewards(1);
    }

    function test_claimUser_reverts_onZeroTo() external {
        uint64[] memory epochs = new uint64[](1);
        epochs[0] = 1;
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolContract.ZeroAddress.selector));
        pool.claimUser(epochs, address(0));
    }

    function test_claimUser_reverts_onEmptyEpochs() external {
        uint64[] memory epochs = new uint64[](0);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolContract.NothingToClaim.selector));
        pool.claimUser(epochs, makeAddr("to"));
    }

    function test_claimUser_reverts_onTooManyEpochs() external {
        uint64[] memory epochs = new uint64[](4);
        epochs[0] = 1;
        epochs[1] = 2;
        epochs[2] = 3;
        epochs[3] = 4;
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolContract.TooManyEpochs.selector, uint256(4), uint256(3)));
        pool.claimUser(epochs, makeAddr("to"));
    }

    function test_claimUser_reverts_onNotStrictlyIncreasing() external {
        uint64[] memory epochs = new uint64[](2);
        epochs[0] = 1;
        epochs[1] = 1;
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolContract.EpochsNotStrictlyIncreasing.selector));
        pool.claimUser(epochs, makeAddr("to"));
    }

    function testFuzz_claimUser_reverts_ifNotStrictlyIncreasing(uint64 b) external {
        // Fuzz case: epochs[0]=1 (already claimed), epochs[1] in {0,1}, always triggers not-strictly-increasing
        uint64[] memory epochs = new uint64[](2);
        epochs[0] = 1;
        epochs[1] = b % 2;

        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolContract.EpochsNotStrictlyIncreasing.selector));
        pool.claimUser(epochs, makeAddr("to"));
    }
}
