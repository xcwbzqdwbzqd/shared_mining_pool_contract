// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2Base} from "./SharedMiningPoolV2Base.t.sol";

/// @notice This test verifies strict EIP-1271 behavior for digest validation.
contract EIP1271StrictV2Test is SharedMiningPoolV2Base {
    /// @notice This test verifies signatures with invalid length are rejected.
    function testRejectInvalidLength() external view {
        bytes memory bad = new bytes(64);
        bytes4 result = pool.isValidSignature(bytes32(uint256(1)), bad);
        assertEq(result, pool.EIP1271_INVALID());
    }

    /// @notice This test verifies valid operator signature over digest returns magic value.
    function testAcceptValidOperatorDigest() external view {
        bytes32 digest = keccak256("test-digest");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = pool.isValidSignature(digest, signature);
        assertEq(result, pool.EIP1271_MAGICVALUE());
    }

    /// @notice This test verifies high-s signature values are rejected.
    function testRejectHighS() external view {
        bytes32 digest = keccak256("high-s");
        (uint8 v, bytes32 r,) = vm.sign(operatorPrivateKey, digest);

        bytes32 highS = bytes32(uint256(0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) + 1);

        bytes memory signature = abi.encodePacked(r, highS, v);
        bytes4 result = pool.isValidSignature(digest, signature);
        assertEq(result, pool.EIP1271_INVALID());
    }
}
