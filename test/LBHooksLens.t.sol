// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "test/TestHelper.sol";

import {ILBHooksBaseRewarder, LBHooksBaseRewarder} from "src/base/LBHooksBaseRewarder.sol";
import "src/delta/LBHooksDeltaMCRewarder.sol";
import "src/delta/LBHooksDeltaExtraRewarder.sol";
import "src/LBHooksLens.sol";

contract LBHooksLensTest is TestHelper {
    LBHooksDeltaMCRewarder lbHooks;
    LBHooksDeltaExtraRewarder lbHooksExtra;
    LBHooksLens lbHooksLens;

    function setUp() public override {
        super.setUp();

        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.DeltaMCRewarder,
            Hooks.setHooks(
                hooksParameters, address(new LBHooksDeltaMCRewarder(address(lbHooksManager), masterchef, moe))
            )
        );
        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.DeltaExtraRewarder,
            Hooks.setHooks(hooksParameters, address(new LBHooksDeltaExtraRewarder(address(lbHooksManager))))
        );

        lbHooks = LBHooksDeltaMCRewarder(
            payable(
                address(
                    lbHooksManager.createLBHooksMCRewarder(
                        ILBHooksManager.LBHooksType.DeltaMCRewarder,
                        IERC20(address(token0)),
                        IERC20(address(token1)),
                        DEFAULT_BIN_STEP,
                        address(this)
                    )
                )
            )
        );

        lbHooksExtra = LBHooksDeltaExtraRewarder(
            payable(
                address(
                    lbHooksManager.createLBHooksExtraRewarder(
                        ILBHooksManager.LBHooksType.DeltaExtraRewarder,
                        IERC20(address(token0)),
                        IERC20(address(token1)),
                        DEFAULT_BIN_STEP,
                        IERC20(address(rewardToken01)),
                        address(this)
                    )
                )
            )
        );

        lbHooksLens = new LBHooksLens(address(lbHooksManager), address(masterchef));

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

        (LBHooksLens.HooksRewarderData memory rewarderData, LBHooksLens.HooksRewarderData memory extraRewarderData) =
            lbHooksLens.getHooksData(address(pair01), address(0), ids);

        assertEq(
            Hooks.encode(rewarderData.hooksParameters),
            pair01.getLBHooksParameters(),
            "test_GetPendingRewardSwapAndTransfer::1"
        );
        assertEq(
            uint8(rewarderData.parameters.hooksType),
            uint8(ILBHooksManager.LBHooksType.DeltaMCRewarder),
            "test_GetPendingRewardSwapAndTransfer::2"
        );
        assertEq(rewarderData.parameters.rewardToken.token, address(moe), "test_GetPendingRewardSwapAndTransfer::3");
        assertEq(rewarderData.parameters.rewardToken.symbol, "MOE", "test_GetPendingRewardSwapAndTransfer::4");
        assertEq(rewarderData.parameters.rewardToken.decimals, 18, "test_GetPendingRewardSwapAndTransfer::5");
        assertEq(rewarderData.parameters.pid, 0, "test_GetPendingRewardSwapAndTransfer::6");
        assertEq(rewarderData.parameters.moePerSecond, 1e18, "test_GetPendingRewardSwapAndTransfer::7");
        assertEq(rewarderData.activeId, DEFAULT_ID, "test_GetPendingRewardSwapAndTransfer::8");
        assertEq(rewarderData.parameters.rangeStart, DEFAULT_ID - 1, "test_GetPendingRewardSwapAndTransfer::9");
        assertEq(rewarderData.parameters.rangeEnd, DEFAULT_ID + 2, "test_GetPendingRewardSwapAndTransfer::10");

        assertEq(
            uint8(extraRewarderData.parameters.hooksType),
            uint8(ILBHooksManager.LBHooksType.DeltaExtraRewarder),
            "test_GetPendingRewardSwapAndTransfer::11"
        );
        assertEq(
            Hooks.encode(extraRewarderData.hooksParameters),
            lbHooks.getExtraHooksParameters(),
            "test_GetPendingRewardSwapAndTransfer::12"
        );
        assertEq(
            extraRewarderData.parameters.rewardToken.token,
            address(rewardToken01),
            "test_GetPendingRewardSwapAndTransfer::13"
        );
        assertEq(extraRewarderData.parameters.rewardToken.symbol, "RT01", "test_GetPendingRewardSwapAndTransfer::14");
        assertEq(extraRewarderData.parameters.rewardToken.decimals, 18, "test_GetPendingRewardSwapAndTransfer::15");
        assertEq(extraRewarderData.parameters.rewardPerSecond, 1e18, "test_GetPendingRewardSwapAndTransfer::16");
        assertEq(
            extraRewarderData.parameters.lastUpdateTimestamp,
            block.timestamp,
            "test_GetPendingRewardSwapAndTransfer::17"
        );
        assertEq(
            extraRewarderData.parameters.endTimestamp, block.timestamp + 100, "test_GetPendingRewardSwapAndTransfer::18"
        );
        assertEq(extraRewarderData.activeId, DEFAULT_ID, "test_GetPendingRewardSwapAndTransfer::19");
        assertEq(extraRewarderData.parameters.rangeStart, DEFAULT_ID, "test_GetPendingRewardSwapAndTransfer::20");
        assertEq(extraRewarderData.parameters.rangeEnd, DEFAULT_ID + 1, "test_GetPendingRewardSwapAndTransfer::21");
        assertEq(extraRewarderData.parameters.remainingRewards, 100e18, "test_GetPendingRewardSwapAndTransfer::22");
        assertTrue(extraRewarderData.parameters.isStarted, "test_GetPendingRewardSwapAndTransfer::23");
        assertFalse(extraRewarderData.parameters.isEnded, "test_GetPendingRewardSwapAndTransfer::24");

        _addLiquidity(pair01, alice, DEFAULT_ID, 1, 10e18, 10e18);
        _addLiquidity(pair01, bob, DEFAULT_ID, 0, 30e18, 30e18);

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), alice, ids);

        assertEq(rewarderData.parameters.pendingRewards, 0, "test_GetPendingRewardSwapAndTransfer::25");
        assertEq(extraRewarderData.parameters.pendingRewards, 0, "test_GetPendingRewardSwapAndTransfer::26");

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), bob, ids);

        assertEq(rewarderData.parameters.pendingRewards, 0, "test_GetPendingRewardSwapAndTransfer::27");
        assertEq(extraRewarderData.parameters.pendingRewards, 0, "test_GetPendingRewardSwapAndTransfer::28");

        vm.warp(block.timestamp + 1);

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), alice, ids);

        assertApproxEqRel(
            rewarderData.parameters.pendingRewards, 0.5e18, 1e15, "test_GetPendingRewardSwapAndTransfer::29"
        );
        assertApproxEqRel(
            extraRewarderData.parameters.pendingRewards, 0.25e18, 1e15, "test_GetPendingRewardSwapAndTransfer::30"
        );

        assertApproxEqRel(
            extraRewarderData.parameters.remainingRewards, 99e18, 1e15, "test_GetPendingRewardSwapAndTransfer::31"
        );

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), bob, ids);

        assertApproxEqRel(
            rewarderData.parameters.pendingRewards, 0.5e18, 1e15, "test_GetPendingRewardSwapAndTransfer::32"
        );
        assertApproxEqRel(
            extraRewarderData.parameters.pendingRewards, 0.75e18, 1e15, "test_GetPendingRewardSwapAndTransfer::33"
        );

        assertApproxEqRel(
            extraRewarderData.parameters.remainingRewards, 99e18, 1e15, "test_GetPendingRewardSwapAndTransfer::34"
        );

        _swap(pair01, address(this), 21e18, 0);

        uint24 activeId = pair01.getActiveId();

        assertEq(activeId, DEFAULT_ID - 1, "test_GetPendingRewardSwapAndTransfer::35");

        vm.warp(block.timestamp + 10);
        _swap(pair01, address(this), 1e18, 0);

        assertEq(pair01.getActiveId(), DEFAULT_ID - 1, "test_GetPendingRewardSwapAndTransfer::36");

        assertEq(moe.balanceOf(address(lbHooks)), 11e18, "test_GetPendingRewardSwapAndTransfer::37");
        assertApproxEqRel(
            extraRewarderData.parameters.remainingRewards, 99e18, 1e15, "test_GetPendingRewardSwapAndTransfer::38"
        );

        assertEq(activeId, DEFAULT_ID - 1, "test_GetPendingRewardSwapAndTransfer::39");

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), alice, ids);

        assertEq(rewarderData.activeId, activeId, "test_GetPendingRewardSwapAndTransfer::40");
        assertApproxEqRel(
            rewarderData.parameters.pendingRewards, 4.5e18, 1e15, "test_GetPendingRewardSwapAndTransfer::41"
        );
        assertApproxEqRel(
            extraRewarderData.parameters.pendingRewards, 10.25e18, 1e15, "test_GetPendingRewardSwapAndTransfer::42"
        );

        assertApproxEqRel(
            extraRewarderData.parameters.remainingRewards, 89e18, 1e15, "test_GetPendingRewardSwapAndTransfer::43"
        );

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), bob, ids);

        assertEq(rewarderData.activeId, activeId, "test_GetPendingRewardSwapAndTransfer::44");
        assertApproxEqRel(
            rewarderData.parameters.pendingRewards, 6.5e18, 1e15, "test_GetPendingRewardSwapAndTransfer::45"
        );
        assertApproxEqRel(
            extraRewarderData.parameters.pendingRewards, 0.75e18, 1e15, "test_GetPendingRewardSwapAndTransfer::46"
        );

        vm.warp(block.timestamp + 90);

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), alice, ids);

        assertApproxEqRel(
            rewarderData.parameters.pendingRewards, 40.5e18, 1e15, "test_GetPendingRewardSwapAndTransfer::47"
        );
        assertApproxEqRel(
            extraRewarderData.parameters.pendingRewards, 99.25e18, 1e15, "test_GetPendingRewardSwapAndTransfer::48"
        );

        assertApproxEqRel(
            extraRewarderData.parameters.remainingRewards, 0, 1e15, "test_GetPendingRewardSwapAndTransfer::49"
        );
        assertTrue(extraRewarderData.parameters.isEnded, "test_GetPendingRewardSwapAndTransfer::50");

        (rewarderData, extraRewarderData) = lbHooksLens.getHooksData(address(pair01), bob, ids);

        assertApproxEqRel(
            rewarderData.parameters.pendingRewards, 60.475e18, 1e15, "test_GetPendingRewardSwapAndTransfer::51"
        );
        assertApproxEqRel(
            extraRewarderData.parameters.pendingRewards, 0.75e18, 1e15, "test_GetPendingRewardSwapAndTransfer::52"
        );
    }
}
