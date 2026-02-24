// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {SharedMiningPoolContract} from "../../src/SharedMiningPoolContract.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockMining} from "../mocks/MockMining.sol";

contract SubmitReceiptBoundaryTest is Test {
    address internal operator;
    address internal feeRecipient;
    address internal user;

    MockERC20 internal botcoin;
    MockMining internal mining;
    SharedMiningPoolContract internal pool;

    function setUp() external {
        operator = makeAddr("operator");
        feeRecipient = makeAddr("feeRecipient");
        user = makeAddr("user");

        botcoin = new MockERC20("Botcoin", "BOT", 18);
        mining = new MockMining(address(botcoin));

        pool = new SharedMiningPoolContract({
            miningContract_: address(mining),
            operator_: operator,
            feeRecipient_: feeRecipient,
            feeBps_: 500,
            depositMode_: SharedMiningPoolContract.DepositMode.Immediate,
            receiptSubmitSelector_: MockMining.submitReceipt.selector,
            maxEpochsPerClaim_: 20
        });

        botcoin.mint(user, 1_000e18);
        vm.prank(user);
        botcoin.approve(address(pool), type(uint256).max);

        mining.setTierBalances(100e18, 200e18, 300e18);
        mining.setEpoch(1);
    }

    function test_onlyOperator() external {
        vm.prank(user);
        pool.deposit(150e18);

        bytes memory miningCalldata = abi.encodeWithSelector(MockMining.submitReceipt.selector, bytes("receipt"));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(SharedMiningPoolContract.OnlyOperator.selector));
        pool.submitReceiptToMining(miningCalldata);
    }

    function test_selectorAllowlist() external {
        vm.prank(user);
        pool.deposit(150e18);

        // Use wrong selector (claim selector used here as an example)
        bytes memory bad = abi.encodeWithSelector(MockMining.claim.selector, new uint64[](0));
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolContract.InvalidSelector.selector,
                MockMining.claim.selector,
                MockMining.submitReceipt.selector
            )
        );
        pool.submitReceiptToMining(bad);
    }

    function test_deltaCreditsMustIncrease() external {
        // Deposit below tier1 so MockMining.submitReceipt produces delta=0
        vm.prank(user);
        pool.deposit(50e18);

        bytes memory miningCalldata = abi.encodeWithSelector(MockMining.submitReceipt.selector, bytes("receipt"));
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SharedMiningPoolContract.CreditsDidNotIncrease.selector, uint64(1), uint64(0), uint64(0)
            )
        );
        pool.submitReceiptToMining(miningCalldata);
    }
}
