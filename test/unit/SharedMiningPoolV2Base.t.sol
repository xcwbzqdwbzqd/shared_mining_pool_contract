// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {SharedMiningPoolV2} from "../../src/SharedMiningPoolV2.sol";
import {MockBonusEpoch} from "../mocks/MockBonusEpoch.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockMiningV2} from "../mocks/MockMiningV2.sol";

/// @notice This abstract base sets up common fixtures for SharedMiningPoolV2 tests.
abstract contract SharedMiningPoolV2Base is Test {
    /// @notice This private key derives operator EOA used by EIP-1271 tests.
    uint256 internal operatorPrivateKey;

    /// @notice This address represents immutable operator in test fixture.
    address internal operator;

    /// @notice This address receives immutable fee in test fixture.
    address internal feeRecipient;

    /// @notice This address represents first user in test fixture.
    address internal user1;

    /// @notice This address represents second user in test fixture.
    address internal user2;

    /// @notice This token mock represents BOTCOIN in test fixture.
    MockERC20 internal botcoin;

    /// @notice This mining mock simulates BotcoinMiningV2 behavior in tests.
    MockMiningV2 internal mining;

    /// @notice This bonus mock simulates BonusEpoch behavior in tests.
    MockBonusEpoch internal bonus;

    /// @notice This pool under test is deployed for each test case.
    SharedMiningPoolV2 internal pool;

    /// @notice This setup initializes token, mocks, pool, and default user approvals.
    function setUp() public virtual {
        operatorPrivateKey = 0xA11CE;
        operator = vm.addr(operatorPrivateKey);
        feeRecipient = makeAddr("feeRecipient");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        botcoin = new MockERC20("BOTCOIN", "BOT", 18);
        mining = new MockMiningV2(address(botcoin));
        bonus = new MockBonusEpoch(address(botcoin));

        pool = new SharedMiningPoolV2({
            mining_: address(mining),
            bonusEpoch_: address(bonus),
            operator_: operator,
            feeRecipient_: feeRecipient,
            feeBps_: 500,
            receiptSubmitSelector_: MockMiningV2.submitReceipt.selector,
            maxEpochsPerClaim_: 50
        });

        mining.setSubmitCreditDelta(address(pool), 1);

        botcoin.mint(user1, 200_000_000e18);
        botcoin.mint(user2, 200_000_000e18);

        vm.prank(user1);
        botcoin.approve(address(pool), type(uint256).max);

        vm.prank(user2);
        botcoin.approve(address(pool), type(uint256).max);
    }

    /// @notice This helper moves mining epoch and triggers pool checkpoint.
    function _rollToEpoch(uint64 epoch) internal {
        mining.setEpoch(epoch);
        pool.checkpointEpoch();
    }
}
