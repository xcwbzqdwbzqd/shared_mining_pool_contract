// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {SharedMiningPoolContract} from "../../src/SharedMiningPoolContract.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockMining} from "../mocks/MockMining.sol";

/// @notice Strict EIP-1271 behavior tests:
/// - accepts only 65-byte ECDSA signatures
/// - enforces low-s validation
/// - never reverts (any input returns magic or invalid)
contract EIP1271Test is Test {
    uint256 internal constant OPERATOR_SK = 0xA11CE;
    address internal operator;

    MockERC20 internal botcoin;
    MockMining internal mining;
    SharedMiningPoolContract internal pool;

    function setUp() external {
        operator = vm.addr(OPERATOR_SK);

        botcoin = new MockERC20("Botcoin", "BOT", 18);
        mining = new MockMining(address(botcoin));

        pool = new SharedMiningPoolContract({
            miningContract_: address(mining),
            operator_: operator,
            feeRecipient_: address(0xBEEF),
            feeBps_: 500,
            depositMode_: SharedMiningPoolContract.DepositMode.Immediate,
            receiptSubmitSelector_: MockMining.submitReceipt.selector,
            maxEpochsPerClaim_: 20
        });
    }

    function test_isValidSignature_returnsMagic_forValidSig() external view {
        bytes32 digest = keccak256("digest");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OPERATOR_SK, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes4 res = pool.isValidSignature(digest, sig);
        assertEq(res, bytes4(0x1626ba7e));
    }

    function test_isValidSignature_acceptsV_0_1() external view {
        bytes32 digest = keccak256("digest2");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OPERATOR_SK, digest);

        // Normalize 27/28 to 0/1 to hit the pool v<27 compatibility path
        uint8 v01 = v - 27;
        bytes memory sig = abi.encodePacked(r, s, v01);

        bytes4 res = pool.isValidSignature(digest, sig);
        assertEq(res, bytes4(0x1626ba7e));
    }

    function test_isValidSignature_rejects_wrongSigner() external view {
        bytes32 digest = keccak256("digest3");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xB0B, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes4 res = pool.isValidSignature(digest, sig);
        assertEq(res, bytes4(0xffffffff));
    }

    function test_isValidSignature_rejects_highS() external view {
        bytes32 digest = keccak256("digest4");
        (uint8 v, bytes32 r, bytes32 sLow) = vm.sign(OPERATOR_SK, digest);

        // secp256k1n
        uint256 n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
        bytes32 sHigh = bytes32(n - uint256(sLow));

        // ecrecover can still recover the same address (with v flipped), but pool must reject high-s
        uint8 vFlip = v == 27 ? 28 : 27;
        bytes memory sig = abi.encodePacked(r, sHigh, vFlip);

        bytes4 res = pool.isValidSignature(digest, sig);
        assertEq(res, bytes4(0xffffffff));
    }

    function testFuzz_isValidSignature_neverReverts(bytes32 digest, bytes calldata signature) external view {
        // Key invariant: function must not revert for any input (coordinator treats revert as invalid)
        // No expectRevert here; test only requires successful return.
        bytes4 res = pool.isValidSignature(digest, signature);
        assertTrue(res == bytes4(0x1626ba7e) || res == bytes4(0xffffffff));
    }
}
