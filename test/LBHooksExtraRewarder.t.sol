// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./TestHelper.sol";

import "../src/LBHooksBaseRewarder.sol";
import "../src/LBHooksRewarder.sol";
import "../src/LBHooksExtraRewarder.sol";

contract LBHooksExtraRewarderTest is TestHelper {
    LBHooksRewarder lbHooks;
    LBHooksExtraRewarder lbHooksExtra;

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

        vm.label(address(lbHooks), "lbHooksRewarder");
        vm.label(address(lbHooksExtra), "lbHooksExtraRewarder");

        delete ids;

        ids.push(DEFAULT_ID - 1);
        ids.push(DEFAULT_ID);
        ids.push(DEFAULT_ID + 1);
    }

    function test_Getters() public {
        assertEq(address(lbHooksExtra.getLBHooksManager()), address(lbHooksManager), "test_Getters::1");
        assertEq(address(lbHooksExtra.getParentRewarder()), address(lbHooks), "test_Getters::2");

        (uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp) =
            lbHooksExtra.getRewarderParameter();

        assertEq(rewardPerSecond, 0, "test_Getters::3");
        assertEq(lastUpdateTimestamp, 0, "test_Getters::4");
        assertEq(endTimestamp, 0, "test_Getters::5");

        assertEq(lbHooksExtra.getRemainingRewards(), 0, "test_Getters::6");
    }

    function test_GetPendingRewardSwapAndTransfer() public {
        lbHooks.setDeltaBins(-1, 2);

        MockERC20(address(rewardToken01)).mint(address(lbHooksExtra), 100e18);
        lbHooksExtra.setDeltaBins(0, 1);
        lbHooksExtra.setRewardPerSecond(1e18, 100);

        _addLiquidity(pair01, alice, DEFAULT_ID, 1, 10e18, 10e18);
        _addLiquidity(pair01, bob, DEFAULT_ID, 0, 30e18, 30e18);

        assertEq(lbHooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::1");
        assertEq(lbHooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::2");

        vm.warp(block.timestamp + 1);

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 0.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::3"
        );
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 0.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::4");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::5"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::6"
        );

        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 99e18, 1e14, "test_GetPendingRewardSwapAndTransfer::7");

        _swap(pair01, address(this), 1e18, 0);
        assertEq(moe.balanceOf(address(lbHooks)), 1e18, "test_GetPendingRewardSwapAndTransfer::8");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 99e18, 1e14, "test_GetPendingRewardSwapAndTransfer::9");

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 0.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::10"
        );
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 0.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::11");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::12"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::13"
        );

        _swap(pair01, address(this), 0, 1e18);
        assertEq(moe.balanceOf(address(lbHooks)), 1e18, "test_GetPendingRewardSwapAndTransfer::14");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 99e18, 1e14, "test_GetPendingRewardSwapAndTransfer::15");

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 0.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::16"
        );
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 0.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::17");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::18"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::19"
        );

        vm.warp(block.timestamp + 9);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::20");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::21");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 2.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::22"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::23"
        );

        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 90e18, 1e14, "test_GetPendingRewardSwapAndTransfer::24");

        lbHooks.setDeltaBins(0, 1);

        assertEq(moe.balanceOf(address(lbHooks)), 10e18, "test_GetPendingRewardSwapAndTransfer::25");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 90e18, 1e14, "test_GetPendingRewardSwapAndTransfer::26");

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::27");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::28");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 2.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::29"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::30"
        );

        vm.warp(block.timestamp + 1);

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 5.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::31"
        );
        assertApproxEqRel(
            lbHooks.getPendingRewards(bob, ids), 5.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::32"
        );

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 2.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::33"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 8.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::34"
        );

        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 89e18, 1e14, "test_GetPendingRewardSwapAndTransfer::35");

        vm.prank(bob);
        pair01.batchTransferFrom(bob, alice, ids, new uint256[](ids.length));

        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 89e18, 1e14, "test_GetPendingRewardSwapAndTransfer::36");

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 5.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::37"
        );
        assertEq(lbHooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::38");
        assertApproxEqRel(moe.balanceOf(bob), 5.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::39");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 2.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::40"
        );
        assertEq(lbHooksExtra.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::41");
        assertApproxEqRel(rewardToken01.balanceOf(bob), 8.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::42");

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        assertEq(lbHooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::43");
        assertEq(lbHooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::44");
        assertApproxEqRel(moe.balanceOf(alice), 5.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::45");

        assertEq(lbHooksExtra.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::46");
        assertEq(lbHooksExtra.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::47");
        assertApproxEqRel(rewardToken01.balanceOf(alice), 2.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::48");

        vm.prank(address(lbHooksManager));
        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__UnlinkedHooks.selector);
        lbHooks.claim(address(this), ids);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__UnauthorizedCaller.selector);
        lbHooksExtra.claim(address(this), ids);
    }
}
