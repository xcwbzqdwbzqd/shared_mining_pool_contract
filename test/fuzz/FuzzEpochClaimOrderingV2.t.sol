// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {SharedMiningPoolV2Base} from "../unit/SharedMiningPoolV2Base.t.sol";

/// @notice This fuzz test validates epoch ordering constraints on claimUser inputs.
contract FuzzEpochClaimOrderingV2Test is SharedMiningPoolV2Base {
    /// @notice This fuzz case ensures non-increasing epoch arrays are rejected.
    function testFuzzRejectNonIncreasingEpochs(uint64 a, uint64) external {
        vm.prank(user1);
        pool.deposit(100e18);

        _rollToEpoch(2);
        pool.stakePrincipal();

        uint64[] memory epochs = new uint64[](2);
        epochs[0] = a;
        epochs[1] = a;

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(SharedMiningPoolV2.InvalidEpochList.selector, uint256(2), pool.maxEpochsPerClaim())
        );
        pool.claimUser(epochs, user1);
        vm.stopPrank();
    }
}
