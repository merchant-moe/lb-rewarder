// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./TestHelper.sol";

import "../src/LBHooksBaseRewarder.sol";
import "../src/LBHooksRewarder.sol";
import "../src/LBHooksExtraRewarder.sol";
import "../src/LBHooksLens.sol";

contract LBHooksLensTest is TestHelper {
    LBHooksRewarder lbHooks;
    LBHooksExtraRewarder lbHooksExtra;
    LBHooksLens lbHooksLens;

    function setUp() public override {
        super.setUp();

        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.Rewarder,
            Hooks.setHooks(hooksParameters, address(new LBHooksRewarder(address(lbHooksManager), masterchef, moe)))
        );
        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.ExtraRewarder,
            Hooks.setHooks(hooksParameters, address(new LBHooksExtraRewarder(address(lbHooksManager))))
        );

        lbHooks = LBHooksRewarder(
            payable(
                address(
                    lbHooksManager.createLBHooksRewarder(
                        IERC20(address(token0)), IERC20(address(token1)), DEFAULT_BIN_STEP, address(this)
                    )
                )
            )
        );

        lbHooksExtra = LBHooksExtraRewarder(
            payable(
                address(
                    lbHooksManager.createLBHooksExtraRewarder(
                        IERC20(address(token0)),
                        IERC20(address(token1)),
                        DEFAULT_BIN_STEP,
                        IERC20(address(rewardToken01)),
                        address(this)
                    )
                )
            )
        );

        lbHooksLens = new LBHooksLens(address(lbHooksManager));

        vm.label(address(lbHooks), "lbHooksRewarder");
        vm.label(address(lbHooksExtra), "lbHooksExtraRewarder");

        delete ids;

        ids.push(DEFAULT_ID - 1);
        ids.push(DEFAULT_ID);
        ids.push(DEFAULT_ID + 1);
    }

    function test_GetPendingRewardSwapAndTransfer() public {
        lbHooks.setDeltaBins(-1, 2);

        MockERC20(address(rewardToken01)).mint(address(lbHooksExtra), 100e18);
        lbHooksExtra.setDeltaBins(0, 1);
        lbHooksExtra.setRewardPerSecond(1e18, 100);

        (LBHooksLens.HooksRewarderData memory rewarderData, LBHooksLens.ExtraHooksRewarderData memory extraRewarderData)
        = lbHooksLens.getHooksData(address(pair01), address(0), ids);

        assertEq(
            Hooks.encode(rewarderData.hooksParameters),
            pair01.getLBHooksParameters(),
            "test_GetPendingRewardSwapAndTransfer::1"
        );
        assertEq(
            uint8(rewarderData.hooksType),
            uint8(ILBHooksManager.LBHooksType.Rewarder),
            "test_GetPendingRewardSwapAndTransfer::2"
        );
        assertEq(rewarderData.rewardToken, address(moe), "test_GetPendingRewardSwapAndTransfer::3");
        assertEq(rewarderData.pid, 0, "test_GetPendingRewardSwapAndTransfer::4");
        assertEq(rewarderData.activeId, DEFAULT_ID, "test_GetPendingRewardSwapAndTransfer::5");
        assertEq(rewarderData.rangeStart, DEFAULT_ID - 1, "test_GetPendingRewardSwapAndTransfer::6");
        assertEq(rewarderData.rangeEnd, DEFAULT_ID + 2, "test_GetPendingRewardSwapAndTransfer::7");

        assertEq(
            uint8(extraRewarderData.hooksType),
            uint8(ILBHooksManager.LBHooksType.ExtraRewarder),
            "test_GetPendingRewardSwapAndTransfer::8"
        );
        assertEq(
            Hooks.encode(extraRewarderData.hooksParameters),
            lbHooks.getExtraHooksParameters(),
            "test_GetPendingRewardSwapAndTransfer::9"
        );
        assertEq(extraRewarderData.rewardToken, address(rewardToken01), "test_GetPendingRewardSwapAndTransfer::10");
        assertEq(extraRewarderData.rewardPerSecond, 1e18, "test_GetPendingRewardSwapAndTransfer::11");
        assertEq(extraRewarderData.lastUpdateTimestamp, block.timestamp, "test_GetPendingRewardSwapAndTransfer::12");
        assertEq(extraRewarderData.endTimestamp, block.timestamp + 100, "test_GetPendingRewardSwapAndTransfer::13");
        assertEq(extraRewarderData.activeId, DEFAULT_ID, "test_GetPendingRewardSwapAndTransfer::14");
        assertEq(extraRewarderData.rangeStart, DEFAULT_ID, "test_GetPendingRewardSwapAndTransfer::15");
        assertEq(extraRewarderData.rangeEnd, DEFAULT_ID + 1, "test_GetPendingRewardSwapAndTransfer::16");
        assertEq(extraRewarderData.remainingRewards, 100e18, "test_GetPendingRewardSwapAndTransfer::17");
        assertTrue(extraRewarderData.isStarted, "test_GetPendingRewardSwapAndTransfer::18");
        assertFalse(extraRewarderData.isEnded, "test_GetPendingRewardSwapAndTransfer::19");

        _addLiquidity(pair01, alice, DEFAULT_ID, 1, 10e18, 10e18);
        _addLiquidity(pair01, bob, DEFAULT_ID, 0, 30e18, 30e18);

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), alice, ids);

        assertEq(rewarderData.pendingRewards, 0, "test_GetPendingRewardSwapAndTransfer::20");
        assertEq(extraRewarderData.pendingRewards, 0, "test_GetPendingRewardSwapAndTransfer::21");

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), bob, ids);

        assertEq(rewarderData.pendingRewards, 0, "test_GetPendingRewardSwapAndTransfer::22");
        assertEq(extraRewarderData.pendingRewards, 0, "test_GetPendingRewardSwapAndTransfer::23");

        vm.warp(block.timestamp + 1);

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), alice, ids);

        assertApproxEqRel(rewarderData.pendingRewards, 0.5e18, 1e15, "test_GetPendingRewardSwapAndTransfer::24");
        assertApproxEqRel(extraRewarderData.pendingRewards, 0.25e18, 1e15, "test_GetPendingRewardSwapAndTransfer::25");

        assertApproxEqRel(extraRewarderData.remainingRewards, 99e18, 1e15, "test_GetPendingRewardSwapAndTransfer::26");

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), bob, ids);

        assertApproxEqRel(rewarderData.pendingRewards, 0.5e18, 1e15, "test_GetPendingRewardSwapAndTransfer::27");
        assertApproxEqRel(extraRewarderData.pendingRewards, 0.75e18, 1e15, "test_GetPendingRewardSwapAndTransfer::28");

        assertApproxEqRel(extraRewarderData.remainingRewards, 99e18, 1e15, "test_GetPendingRewardSwapAndTransfer::29");

        _swap(pair01, address(this), 21e18, 0);

        uint24 activeId = pair01.getActiveId();

        assertEq(activeId, DEFAULT_ID - 1, "test_GetPendingRewardSwapAndTransfer::30");

        vm.warp(block.timestamp + 10);
        _swap(pair01, address(this), 1e18, 0);

        assertEq(pair01.getActiveId(), DEFAULT_ID - 1, "test_GetPendingRewardSwapAndTransfer::31");

        assertEq(moe.balanceOf(address(lbHooks)), 11e18, "test_GetPendingRewardSwapAndTransfer::32");
        assertApproxEqRel(extraRewarderData.remainingRewards, 99e18, 1e15, "test_GetPendingRewardSwapAndTransfer::33");

        assertEq(activeId, DEFAULT_ID - 1, "test_GetPendingRewardSwapAndTransfer::34");

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), alice, ids);

        assertEq(rewarderData.activeId, activeId, "test_GetPendingRewardSwapAndTransfer::35");
        assertApproxEqRel(rewarderData.pendingRewards, 4.5e18, 1e15, "test_GetPendingRewardSwapAndTransfer::36");
        assertApproxEqRel(extraRewarderData.pendingRewards, 10.25e18, 1e15, "test_GetPendingRewardSwapAndTransfer::37");

        assertApproxEqRel(extraRewarderData.remainingRewards, 89e18, 1e15, "test_GetPendingRewardSwapAndTransfer::38");

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), bob, ids);

        assertEq(rewarderData.activeId, activeId, "test_GetPendingRewardSwapAndTransfer::39");
        assertApproxEqRel(rewarderData.pendingRewards, 6.5e18, 1e15, "test_GetPendingRewardSwapAndTransfer::40");
        assertApproxEqRel(extraRewarderData.pendingRewards, 0.75e18, 1e15, "test_GetPendingRewardSwapAndTransfer::41");

        vm.warp(block.timestamp + 90);

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), alice, ids);

        assertApproxEqRel(rewarderData.pendingRewards, 40.5e18, 1e15, "test_GetPendingRewardSwapAndTransfer::42");
        assertApproxEqRel(extraRewarderData.pendingRewards, 99.25e18, 1e15, "test_GetPendingRewardSwapAndTransfer::43");

        assertApproxEqRel(extraRewarderData.remainingRewards, 0, 1e15, "test_GetPendingRewardSwapAndTransfer::44");
        assertTrue(extraRewarderData.isEnded, "test_GetPendingRewardSwapAndTransfer::45");

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), bob, ids);

        assertApproxEqRel(rewarderData.pendingRewards, 60.475e18, 1e15, "test_GetPendingRewardSwapAndTransfer::46");
        assertApproxEqRel(extraRewarderData.pendingRewards, 0.75e18, 1e15, "test_GetPendingRewardSwapAndTransfer::47");
    }
}
