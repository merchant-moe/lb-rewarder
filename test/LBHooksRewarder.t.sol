// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./TestHelper.sol";

import "../src/LBHooksMCRewarder.sol";
import "../src/interfaces/ILBHooksBaseRewarder.sol";

contract LBHooksRewarderTest is TestHelper {
    LBHooksMCRewarder lbHooks;

    function setUp() public override {
        super.setUp();

        hooksParameters =
            Hooks.setHooks(hooksParameters, address(new LBHooksMCRewarder(address(lbHooksManager), masterchef, moe)));

        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.MCRewarder, hooksParameters);

        lbHooks = LBHooksMCRewarder(
            payable(
                address(
                    lbHooksManager.createLBHooksMCRewarder(
                        IERC20(address(token0)), IERC20(address(token1)), DEFAULT_BIN_STEP, address(this)
                    )
                )
            )
        );

        vm.label(address(lbHooks), "lbHooks");
    }

    function test_Getters() public {
        assertEq(address(lbHooks.getLBHooksManager()), address(lbHooksManager), "test_Getters::1");
        assertEq(address(lbHooks.getMasterChef()), address(masterchef), "test_Getters::2");
        assertEq(address(lbHooks.getRewardToken()), address(moe), "test_Getters::3");
        assertEq(address(lbHooks.getLBPair()), address(pair01), "test_Getters::4");
        assertEq(lbHooks.getPid(), masterchef.getNumberOfFarms() - 1, "test_Getters::5");
        assertEq(lbHooks.getPendingRewards(address(this), ids), 0, "test_Getters::6");
        assertEq(keccak256(bytes(lbHooks.symbol())), keccak256("Vote LB T0-T1:25"), "test_Getters::7");
        assertEq(keccak256(bytes(lbHooks.name())), keccak256("LB Hooks Moe Rewarder"), "test_Getters::8");
    }

    function test_GetPendingRewardSwapAndTransfer() public {
        _addLiquidity(pair01, alice, DEFAULT_ID, 2, 10e18, 10e18);
        _addLiquidity(pair01, bob, DEFAULT_ID, 1, 30e18, 30e18);

        lbHooks.setDeltaBins(-1, 2);

        assertEq(lbHooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::1");
        assertEq(lbHooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::2");

        vm.warp(block.timestamp + 1);

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::3"
        );
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::4");

        _swap(pair01, address(this), 1e18, 0);
        assertEq(moe.balanceOf(address(lbHooks)), 1e18, "test_GetPendingRewardSwapAndTransfer::5");

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::6"
        );
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::7");

        _swap(pair01, address(this), 0, 1e18);
        assertEq(moe.balanceOf(address(lbHooks)), 1e18, "test_GetPendingRewardSwapAndTransfer::8");

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::9"
        );
        assertApproxEqRel(
            lbHooks.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::10"
        );

        vm.warp(block.timestamp + 9);

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 2.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::11"
        );
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::12");

        lbHooks.setDeltaBins(-2, -1);

        assertEq(moe.balanceOf(address(lbHooks)), 10e18, "test_GetPendingRewardSwapAndTransfer::13");

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 2.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::14"
        );
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::15");

        vm.warp(block.timestamp + 1);

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 3.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::16"
        );
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::17");

        vm.prank(bob);
        pair01.batchTransferFrom(bob, alice, ids, new uint256[](ids.length));

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 3.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::18"
        );
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::19");
        assertEq(moe.balanceOf(bob), 0, "test_GetPendingRewardSwapAndTransfer::20");

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        assertEq(lbHooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::21");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::22");
        assertApproxEqRel(moe.balanceOf(alice), 3.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::23");

        vm.warp(block.timestamp + 1);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 1e18, 1e14, "test_GetPendingRewardSwapAndTransfer::24");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::25");

        MockERC20(address(moe)).mint(address(lbHooks), 1e18);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 2e18, 1e14, "test_GetPendingRewardSwapAndTransfer::26");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::27");

        vm.prank(address(lbHooksManager));
        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__UnlinkedHooks.selector);
        lbHooks.claim(address(this), ids);
    }
}
