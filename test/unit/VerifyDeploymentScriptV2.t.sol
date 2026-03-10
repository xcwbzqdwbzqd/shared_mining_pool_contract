// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {VerifyDeploymentV2} from "../../script/VerifyDeploymentV2.s.sol";
import {MockPoolViewV2} from "../mocks/MockPoolViewV2.sol";

/// @notice This test verifies post-deploy baseline check script behavior.
contract VerifyDeploymentScriptV2Test is Test {
    /// @notice This helper returns a mock pool configured with the expected baseline values.
    function deployMockPool() internal returns (MockPoolViewV2) {
        return new MockPoolViewV2(
            address(0x1001), address(0x2002), address(0x3003), address(0x4004), 500, 20, bytes4(0xf9b5aac1)
        );
    }

    /// @notice This test verifies wrong fee basis points triggers baseline mismatch.
    function testVerifyRevertsOnWrongFeeBps() external {
        MockPoolViewV2 pool = new MockPoolViewV2(
            address(0x1001), address(0x2002), address(0x3003), address(0x4004), 600, 20, bytes4(0xf9b5aac1)
        );
        VerifyDeploymentV2 verifier = new VerifyDeploymentV2();

        vm.expectRevert(abi.encodeWithSelector(VerifyDeploymentV2.BaselineMismatch.selector));
        verifier.assertMainnetBaseline(
            address(pool), address(0x1001), address(0x2002), address(0x3003), address(0x4004)
        );
    }

    /// @notice This test verifies wrong max epochs triggers baseline mismatch.
    function testVerifyRevertsOnWrongMaxEpochs() external {
        MockPoolViewV2 pool = new MockPoolViewV2(
            address(0x1001), address(0x2002), address(0x3003), address(0x4004), 500, 21, bytes4(0xf9b5aac1)
        );
        VerifyDeploymentV2 verifier = new VerifyDeploymentV2();

        vm.expectRevert(abi.encodeWithSelector(VerifyDeploymentV2.BaselineMismatch.selector));
        verifier.assertMainnetBaseline(
            address(pool), address(0x1001), address(0x2002), address(0x3003), address(0x4004)
        );
    }

    /// @notice This test verifies wrong mining address triggers baseline mismatch.
    function testVerifyRevertsOnWrongMining() external {
        MockPoolViewV2 pool = deployMockPool();
        VerifyDeploymentV2 verifier = new VerifyDeploymentV2();

        vm.expectRevert(abi.encodeWithSelector(VerifyDeploymentV2.BaselineMismatch.selector));
        verifier.assertMainnetBaseline(
            address(pool), address(0x9999), address(0x2002), address(0x3003), address(0x4004)
        );
    }

    /// @notice This test verifies wrong bonus contract triggers baseline mismatch.
    function testVerifyRevertsOnWrongBonusEpoch() external {
        MockPoolViewV2 pool = deployMockPool();
        VerifyDeploymentV2 verifier = new VerifyDeploymentV2();

        vm.expectRevert(abi.encodeWithSelector(VerifyDeploymentV2.BaselineMismatch.selector));
        verifier.assertMainnetBaseline(
            address(pool), address(0x1001), address(0x9999), address(0x3003), address(0x4004)
        );
    }

    /// @notice This test verifies wrong operator triggers baseline mismatch.
    function testVerifyRevertsOnWrongOperator() external {
        MockPoolViewV2 pool = deployMockPool();
        VerifyDeploymentV2 verifier = new VerifyDeploymentV2();

        vm.expectRevert(abi.encodeWithSelector(VerifyDeploymentV2.BaselineMismatch.selector));
        verifier.assertMainnetBaseline(
            address(pool), address(0x1001), address(0x2002), address(0x9999), address(0x4004)
        );
    }

    /// @notice This test verifies wrong fee recipient triggers baseline mismatch.
    function testVerifyRevertsOnWrongFeeRecipient() external {
        MockPoolViewV2 pool = deployMockPool();
        VerifyDeploymentV2 verifier = new VerifyDeploymentV2();

        vm.expectRevert(abi.encodeWithSelector(VerifyDeploymentV2.BaselineMismatch.selector));
        verifier.assertMainnetBaseline(
            address(pool), address(0x1001), address(0x2002), address(0x3003), address(0x9999)
        );
    }

    /// @notice This test verifies wrong selector triggers baseline mismatch.
    function testVerifyRevertsOnWrongSelector() external {
        MockPoolViewV2 pool = new MockPoolViewV2(
            address(0x1001), address(0x2002), address(0x3003), address(0x4004), 500, 20, bytes4(0x12345678)
        );
        VerifyDeploymentV2 verifier = new VerifyDeploymentV2();

        vm.expectRevert(abi.encodeWithSelector(VerifyDeploymentV2.BaselineMismatch.selector));
        verifier.assertMainnetBaseline(
            address(pool), address(0x1001), address(0x2002), address(0x3003), address(0x4004)
        );
    }

    /// @notice This test verifies baseline check passes when all values match.
    function testVerifyPassesWithExpectedBaselines() external {
        MockPoolViewV2 pool = deployMockPool();
        VerifyDeploymentV2 verifier = new VerifyDeploymentV2();
        verifier.assertMainnetBaseline(
            address(pool), address(0x1001), address(0x2002), address(0x3003), address(0x4004)
        );
    }
}
