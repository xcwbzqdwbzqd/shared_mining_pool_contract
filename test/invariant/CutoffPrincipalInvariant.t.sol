// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";

import {EscrowVault} from "../../src/EscrowVault.sol";
import {SharedMiningPoolContract} from "../../src/SharedMiningPoolContract.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockMining} from "../mocks/MockMining.sol";

/// @notice Cutoff-mode principal invariants (claimRewards is not triggered to avoid reward-balance interference).
/// Invariants:
/// - pool balance == totalActiveShares (active principal)
/// - vault balance == scheduledActivationShares[currentEpoch+1] (pending principal activates only next epoch)
contract CutoffPrincipalInvariant is StdInvariant, Test {
    MockERC20 internal botcoin;
    MockMining internal mining;
    SharedMiningPoolContract internal pool;

    CutoffHandler internal handler;

    function setUp() external {
        botcoin = new MockERC20("Botcoin", "BOT", 18);
        mining = new MockMining(address(botcoin));
        mining.setTierBalances(100e18, 500e18, 1_000e18);
        mining.setEpoch(1);

        pool = new SharedMiningPoolContract({
            miningContract_: address(mining),
            operator_: makeAddr("operator"),
            feeRecipient_: makeAddr("feeRecipient"),
            feeBps_: 500,
            depositMode_: SharedMiningPoolContract.DepositMode.NextEpochCutoff,
            receiptSubmitSelector_: MockMining.submitReceipt.selector,
            maxEpochsPerClaim_: 20
        });

        handler = new CutoffHandler(botcoin, mining, pool);
        targetContract(address(handler));
    }

    function invariant_activeBalanceEqualsActiveShares() external view {
        assertEq(botcoin.balanceOf(address(pool)), pool.totalActiveShares());
    }

    function invariant_vaultBalanceMatchesScheduledNextEpoch() external view {
        uint64 cur = mining.currentEpoch();
        EscrowVault v = pool.vault();
        assertEq(botcoin.balanceOf(address(v)), pool.scheduledActivationShares(cur + 1));
    }
}

contract CutoffHandler is Test {
    MockERC20 internal botcoin;
    MockMining internal mining;
    SharedMiningPoolContract internal pool;

    address internal operator;
    address[] internal actors;

    constructor(MockERC20 botcoin_, MockMining mining_, SharedMiningPoolContract pool_) {
        botcoin = botcoin_;
        mining = mining_;
        pool = pool_;

        operator = pool.operator();

        actors.push(makeAddr("c1"));
        actors.push(makeAddr("c2"));
        actors.push(makeAddr("c3"));

        for (uint256 i = 0; i < actors.length; i++) {
            botcoin.mint(actors[i], 100_000e18);
            vm.prank(actors[i]);
            botcoin.approve(address(pool), type(uint256).max);
        }
    }

    function deposit(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        uint256 a = bound(amount, 1e18, 1_000e18);

        vm.prank(actor);
        pool.deposit(a);
    }

    function withdraw(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];

        (,, uint256 unlocked,) = pool.getUserPrincipalState(actor);
        if (unlocked == 0) {
            return;
        }

        uint256 a = bound(amount, 1, unlocked);
        vm.prank(actor);
        pool.withdraw(a, actor);
    }

    function submitReceipt(uint256 salt) external {
        // Submit only after reaching tier1; otherwise call can revert (Δcredits==0 or NoActiveShares)
        if (pool.totalActiveShares() == 0) {
            return;
        }
        if (botcoin.balanceOf(address(pool)) < mining.tier1Balance()) {
            return;
        }

        bytes memory miningCalldata = abi.encodeWithSelector(MockMining.submitReceipt.selector, abi.encodePacked(salt));
        vm.prank(operator);
        pool.submitReceiptToMining(miningCalldata);
    }

    function advanceEpoch() external {
        uint64 cur = mining.currentEpoch();
        mining.setEpoch(cur + 1);

        // Explicit checkpoint activates and clears scheduledActivationShares[cur], preserving O(1) invariant checks
        pool.checkpointEpoch();
    }
}
