// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./TestHelper.sol";

import {ILBPair} from "@lb-protocol/src/interfaces/ILBPair.sol";

import "../src/LBHooksMCRewarder.sol";
import "../src/LBHooksExtraRewarder.sol";
import "../src/interfaces/ILBHooksBaseRewarder.sol";

/**
 * @dev Regression tests for the reentrancy issue where a native-paying extra rewarder's
 * payout callback reenters the parent MC rewarder while its MOE is still in flight.
 *
 * The parent settles its MOE (accounting + transfer) before calling the extra rewarder, so
 * `balance - _totalUnclaimedRewards` is consistent during any callback. These tests exercise
 * both the direct `claim` reentry and the reentry through the unguarded LB hooks.
 */
contract LBHooksMCRewarderReentrancyTest is TestHelper {
    LBHooksMCRewarder lbHooks;
    LBHooksExtraRewarder lbHooksExtra;
    ReentrantClaimer attacker;

    function setUp() public override {
        super.setUp();

        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.MCRewarder,
            Hooks.setHooks(hooksParameters, address(new LBHooksMCRewarder(address(lbHooksManager), masterchef, moe)))
        );
        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.ExtraRewarder,
            Hooks.setHooks(hooksParameters, address(new LBHooksExtraRewarder(address(lbHooksManager))))
        );

        lbHooks = LBHooksMCRewarder(
            payable(address(
                    lbHooksManager.createLBHooksMCRewarder(
                        IERC20(address(token0)), IERC20(address(token1)), DEFAULT_BIN_STEP, address(this)
                    )
                ))
        );

        lbHooksExtra = LBHooksExtraRewarder(
            payable(address(
                    lbHooksManager.createLBHooksExtraRewarder(
                        IERC20(address(token0)),
                        IERC20(address(token1)),
                        DEFAULT_BIN_STEP,
                        IERC20(address(0)),
                        address(this)
                    )
                ))
        );

        vm.label(address(lbHooks), "lbHooksRewarder");
        vm.label(address(lbHooksExtra), "lbHooksExtraRewarder");

        attacker = new ReentrantClaimer(lbHooks, pair01, ids);
        vm.label(address(attacker), "attacker");
    }

    /// @dev Funds the native extra rewarder and seeds the attacker with a 10% liquidity share.
    function _setup() internal {
        lbHooks.setDeltaBins(0, 1);
        lbHooksExtra.setDeltaBins(0, 1);

        vm.deal(address(lbHooksExtra), 100e18);
        lbHooksExtra.setRewardPerSecond(1e18, 100);

        _addLiquidity(pair01, address(attacker), DEFAULT_ID, 0, 10e18, 10e18);
        _addLiquidity(pair01, bob, DEFAULT_ID, 0, 90e18, 90e18);

        vm.warp(block.timestamp + 10);
    }

    function test_HonestClaimWithNativeExtraRewarder() public {
        _setup();

        uint256 pendingMoe = lbHooks.getPendingRewards(address(attacker), ids);
        uint256 pendingNative = lbHooksExtra.getPendingRewards(address(attacker), ids);

        assertGt(pendingMoe, 0, "test_HonestClaimWithNativeExtraRewarder::1");
        assertGt(pendingNative, 0, "test_HonestClaimWithNativeExtraRewarder::2");

        attacker.setMode(ReentrantClaimer.Mode.None);
        attacker.claim();

        assertApproxEqAbs(moe.balanceOf(address(attacker)), pendingMoe, 1, "test_HonestClaimWithNativeExtraRewarder::3");
        assertApproxEqAbs(address(attacker).balance, pendingNative, 1, "test_HonestClaimWithNativeExtraRewarder::4");

        _assertBobUnharmed();
    }

    function test_ReentrantClaimDoesNotInflateMoe() public {
        _setup();

        uint256 pendingMoe = lbHooks.getPendingRewards(address(attacker), ids);
        uint256 pendingNative = lbHooksExtra.getPendingRewards(address(attacker), ids);

        attacker.setMode(ReentrantClaimer.Mode.ReenterClaim);
        attacker.claim();

        // The reentrant claim must not pay the attacker more than its honest share of either token.
        assertApproxEqAbs(moe.balanceOf(address(attacker)), pendingMoe, 1, "test_ReentrantClaimDoesNotInflateMoe::1");
        assertApproxEqAbs(address(attacker).balance, pendingNative, 1, "test_ReentrantClaimDoesNotInflateMoe::2");

        // No phantom pending is observable mid-claim: the MOE is settled before the callback fires.
        assertApproxEqAbs(attacker.pendingDuringCallback(), 0, 1, "test_ReentrantClaimDoesNotInflateMoe::3");

        _assertBobUnharmed();
    }

    function test_ReentrantClaimViaHookDoesNotCorruptAccounting() public {
        _setup();

        uint256 pendingMoe = lbHooks.getPendingRewards(address(attacker), ids);
        uint256 pendingNative = lbHooksExtra.getPendingRewards(address(attacker), ids);

        // Reenter through an LB hook (self batchTransferFrom) rather than `claim` directly.
        // This path is not covered by a `claim` reentrancy guard, so only the settle-before-call
        // ordering protects it. swap/mint/burn reach the same `_updateAccruedRewardsPerShare`.
        attacker.setMode(ReentrantClaimer.Mode.ReenterHook);
        attacker.claim();

        assertApproxEqAbs(
            moe.balanceOf(address(attacker)), pendingMoe, 1, "test_ReentrantClaimViaHookDoesNotCorruptAccounting::1"
        );
        assertApproxEqAbs(
            address(attacker).balance, pendingNative, 1, "test_ReentrantClaimViaHookDoesNotCorruptAccounting::2"
        );
        assertApproxEqAbs(
            attacker.pendingDuringCallback(), 0, 1, "test_ReentrantClaimViaHookDoesNotCorruptAccounting::3"
        );

        // On the vulnerable ordering this desyncs `_totalUnclaimedRewards` above the balance and
        // the next pending computation underflows and reverts.
        _assertBobUnharmed();
    }

    function test_ReentrantClaimOnlyExtraRewarderEmptyMainPool() public {
        // Leave the main pool range empty (default deltaBins 0,0) so the attacker has no MOE to claim,
        // exercising the `rewards == 0` branch while the native extra rewarder still fires the callback.
        lbHooksExtra.setDeltaBins(0, 1);

        vm.deal(address(lbHooksExtra), 100e18);
        lbHooksExtra.setRewardPerSecond(1e18, 100);

        _addLiquidity(pair01, address(attacker), DEFAULT_ID, 0, 10e18, 10e18);
        _addLiquidity(pair01, bob, DEFAULT_ID, 0, 90e18, 90e18);

        vm.warp(block.timestamp + 10);

        uint256 pendingNative = lbHooksExtra.getPendingRewards(address(attacker), ids);
        assertGt(pendingNative, 0, "test_ReentrantClaimOnlyExtraRewarderEmptyMainPool::1");

        attacker.setMode(ReentrantClaimer.Mode.ReenterClaim);
        attacker.claim();

        assertEq(moe.balanceOf(address(attacker)), 0, "test_ReentrantClaimOnlyExtraRewarderEmptyMainPool::2");
        assertApproxEqAbs(
            address(attacker).balance, pendingNative, 1, "test_ReentrantClaimOnlyExtraRewarderEmptyMainPool::3"
        );
    }

    /// @dev Bob keeps his fair share and the accounting stays readable/claimable after the attack.
    function _assertBobUnharmed() internal {
        uint256 bobPending = lbHooks.getPendingRewards(bob, ids);
        assertApproxEqRel(bobPending, 9e18, 1e14, "_assertBobUnharmed::1");

        vm.prank(bob);
        lbHooks.claim(bob, ids);

        assertApproxEqAbs(moe.balanceOf(bob), bobPending, 1, "_assertBobUnharmed::2");
    }
}

contract ReentrantClaimer {
    enum Mode {
        None,
        ReenterClaim,
        ReenterHook
    }

    ILBHooksBaseRewarder public immutable lbHooks;
    ILBPair public immutable pair;

    uint256[] internal _ids;
    Mode internal _mode;
    bool internal _entered;

    /// @dev `getPendingRewards` for this contract, read from inside the payout callback.
    uint256 public pendingDuringCallback;

    constructor(ILBHooksBaseRewarder lbHooks_, ILBPair pair_, uint256[] memory ids_) {
        lbHooks = lbHooks_;
        pair = pair_;
        _ids = ids_;
    }

    function setMode(Mode mode) external {
        _mode = mode;
    }

    function claim() external {
        _entered = false;
        lbHooks.claim(address(this), _ids);
    }

    receive() external payable {
        if (_entered) return;
        _entered = true;

        pendingDuringCallback = lbHooks.getPendingRewards(address(this), _ids);

        if (_mode == Mode.ReenterClaim) {
            lbHooks.claim(address(this), _ids);
        } else if (_mode == Mode.ReenterHook) {
            pair.batchTransferFrom(address(this), address(this), _ids, new uint256[](_ids.length));
        }
    }
}
