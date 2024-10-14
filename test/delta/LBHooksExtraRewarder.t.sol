// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "test/TestHelper.sol";

import "src/base/LBHooksBaseRewarder.sol";
import "src/base/LBHooksBaseSimpleRewarder.sol";
import "src/delta/LBHooksDeltaMCRewarder.sol";
import "src/delta/LBHooksDeltaExtraRewarder.sol";

contract LBHooksExtraRewarderTest is TestHelper {
    LBHooksDeltaMCRewarder lbHooks;
    LBHooksDeltaExtraRewarder lbHooksExtra;

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
                        IERC20(address(token0)), IERC20(address(token1)), DEFAULT_BIN_STEP, address(this)
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
        assertApproxEqRel(
            lbHooks.getPendingRewards(bob, ids), 5.75e18, 1e15, "test_GetPendingRewardSwapAndTransfer::38"
        );
        assertEq(moe.balanceOf(bob), 0, "test_GetPendingRewardSwapAndTransfer::39");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 2.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::40"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 8.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::41"
        );
        assertEq(rewardToken01.balanceOf(bob), 0, "test_GetPendingRewardSwapAndTransfer::42");

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        assertEq(lbHooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::43");
        assertApproxEqRel(
            lbHooks.getPendingRewards(bob, ids), 5.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::44"
        );
        assertApproxEqRel(moe.balanceOf(alice), 5.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::45");

        assertEq(lbHooksExtra.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::46");
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 8.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::47"
        );
        assertApproxEqRel(rewardToken01.balanceOf(alice), 2.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::48");

        vm.warp(block.timestamp + 10);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__UnauthorizedCaller.selector);
        lbHooksExtra.claim(address(this), ids);

        lbHooks.setLBHooksExtraRewarder(address(0), new bytes(0));

        assertFalse(lbHooksExtra.isLinked(), "test_GetPendingRewardSwapAndTransfer::49");

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 2.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::50"
        );
        assertApproxEqRel(
            lbHooks.getPendingRewards(bob, ids), 5.75e18 + 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::51"
        );

        assertEq(lbHooksExtra.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::52");
        assertEq(lbHooksExtra.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::53");

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        assertEq(lbHooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::54");
        assertApproxEqRel(
            lbHooks.getPendingRewards(bob, ids), 5.75e18 + 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::55"
        );
        assertApproxEqRel(moe.balanceOf(alice), 5.25e18 + 2.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::56");

        assertEq(lbHooksExtra.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::57");
        assertEq(lbHooksExtra.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::58");

        vm.prank(address(lbHooksManager));
        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__UnlinkedHooks.selector);
        lbHooks.claim(address(this), ids);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__UnlinkedHooks.selector);
        lbHooksExtra.claim(address(this), ids);

        assertEq(lbHooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::59");
        assertEq(lbHooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::60");

        assertEq(lbHooksExtra.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::61");
        assertEq(lbHooksExtra.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::62");
    }

    function test_GetPendingRewardMintAndBurn() public {
        lbHooks.setDeltaBins(-1, 2);

        MockERC20(address(rewardToken01)).mint(address(lbHooksExtra), 100e18);
        lbHooksExtra.setDeltaBins(0, 1);
        lbHooksExtra.setRewardPerSecond(1e18, 100);

        vm.warp(block.timestamp + 1);

        _addLiquidity(pair01, alice, DEFAULT_ID, 1, 10e18, 10e18);
        _addLiquidity(pair01, bob, DEFAULT_ID, 0, 30e18, 30e18);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 1e18, 1e14, "test_GetPendingRewardMintAndBurn::1");

        assertApproxEqRel(lbHooksExtra.getPendingRewards(alice, ids), 0, 1e14, "test_GetPendingRewardMintAndBurn::2");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 100e18, 1e14, "test_GetPendingRewardMintAndBurn::3");

        vm.warp(block.timestamp + 4);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 3e18, 1e14, "test_GetPendingRewardMintAndBurn::4");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 2e18, 1e14, "test_GetPendingRewardMintAndBurn::5");

        assertApproxEqRel(lbHooksExtra.getPendingRewards(alice, ids), 1e18, 1e14, "test_GetPendingRewardMintAndBurn::6");
        assertApproxEqRel(lbHooksExtra.getPendingRewards(bob, ids), 3e18, 1e14, "test_GetPendingRewardMintAndBurn::7");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 96e18, 1e14, "test_GetPendingRewardMintAndBurn::8");

        vm.warp(block.timestamp + 4);

        _removeLiquidity(pair01, bob, DEFAULT_ID, 0, uint256(2e18) / 3);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 5e18, 1e14, "test_GetPendingRewardMintAndBurn::9");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 4e18, 1e14, "test_GetPendingRewardMintAndBurn::10");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 2e18, 1e14, "test_GetPendingRewardMintAndBurn::11"
        );
        assertApproxEqRel(lbHooksExtra.getPendingRewards(bob, ids), 6e18, 1e14, "test_GetPendingRewardMintAndBurn::12");

        assertEq(moe.balanceOf(bob), 0, "test_GetPendingRewardMintAndBurn::13");
        assertEq(rewardToken01.balanceOf(bob), 0, "test_GetPendingRewardMintAndBurn::14");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 92e18, 1e14, "test_GetPendingRewardMintAndBurn::15");

        vm.warp(block.timestamp + 4);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 8e18, 1e14, "test_GetPendingRewardMintAndBurn::16");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 5e18, 1e14, "test_GetPendingRewardMintAndBurn::17");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 4e18, 1e14, "test_GetPendingRewardMintAndBurn::18"
        );
        assertApproxEqRel(lbHooksExtra.getPendingRewards(bob, ids), 8e18, 1e14, "test_GetPendingRewardMintAndBurn::19");

        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 88e18, 1e14, "test_GetPendingRewardMintAndBurn::20");

        vm.warp(block.timestamp + 87);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 73.25e18, 1e14, "test_GetPendingRewardMintAndBurn::21");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 26.75e18, 1e14, "test_GetPendingRewardMintAndBurn::22");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 51.5e18, 1e14, "test_GetPendingRewardMintAndBurn::23"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 47.5e18, 1e14, "test_GetPendingRewardMintAndBurn::24"
        );
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 1e18, 1e14, "test_GetPendingRewardMintAndBurn::25");

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        vm.prank(bob);
        lbHooks.claim(bob, ids);

        assertApproxEqRel(rewardToken01.balanceOf(bob), 51.5e18, 1e14, "test_GetPendingRewardMintAndBurn::26");
        assertApproxEqRel(rewardToken01.balanceOf(alice), 47.5e18, 1e14, "test_GetPendingRewardMintAndBurn::27");

        vm.warp(block.timestamp + 1);

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        assertApproxEqRel(rewardToken01.balanceOf(bob), 51.5e18, 1e14, "test_GetPendingRewardMintAndBurn::28");
        assertApproxEqRel(rewardToken01.balanceOf(alice), 47.5e18, 1e14, "test_GetPendingRewardMintAndBurn::29");

        vm.warp(block.timestamp + 1);

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        assertApproxEqRel(rewardToken01.balanceOf(bob), 51.5e18, 1e14, "test_GetPendingRewardMintAndBurn::30");
        assertApproxEqRel(rewardToken01.balanceOf(alice), 47.5e18, 1e14, "test_GetPendingRewardMintAndBurn::31");
    }

    function test_RemoveExtraRewarder() public {
        lbHooks.setLBHooksExtraRewarder(address(0), new bytes(0));
    }

    function test_SetBadExtraRewarder() public {
        MockExtraHook extraHook = new MockExtraHook();

        vm.expectRevert(ILBHooksBaseParentRewarder.LBHooksRewarder__InvalidLBHooksExtraRewarder.selector);
        lbHooks.setLBHooksExtraRewarder(address(extraHook), new bytes(0));

        extraHook.setLBPair(address(pair01));

        vm.expectRevert(ILBHooksBaseParentRewarder.LBHooksRewarder__InvalidLBHooksExtraRewarder.selector);
        lbHooks.setLBHooksExtraRewarder(address(extraHook), new bytes(0));
    }

    function test_fuzz_SetBadExtraRewarder(address lbPair, address parentRewarder) public {
        vm.assume(lbPair != address(pair01) || parentRewarder != address(lbHooks));

        MockExtraHook extraHook = new MockExtraHook();

        extraHook.setLBPair(lbPair);
        extraHook.setParentRewarder(parentRewarder);

        vm.expectRevert(ILBHooksBaseParentRewarder.LBHooksRewarder__InvalidLBHooksExtraRewarder.selector);
        lbHooks.setLBHooksExtraRewarder(address(extraHook), new bytes(0));
    }

    function test_fuzz_SetRewardsParameters(
        uint256 maxRewardPerSecond,
        uint256 startTimestamp,
        uint256 expectedDuration
    ) public {
        startTimestamp = bound(startTimestamp, 0, block.timestamp - 1);

        vm.expectRevert(ILBHooksBaseSimpleRewarder.LBHooksBaseSimpleRewarder__InvalidStartTimestamp.selector);
        lbHooksExtra.setRewarderParameters(maxRewardPerSecond, startTimestamp, expectedDuration);

        startTimestamp = bound(startTimestamp, block.timestamp, type(uint256).max);

        expectedDuration = bound(expectedDuration, 1, type(uint256).max - startTimestamp);
        maxRewardPerSecond = bound(maxRewardPerSecond, 1, type(uint256).max / expectedDuration);

        vm.expectRevert(ILBHooksBaseSimpleRewarder.LBHooksBaseSimpleRewarder__InvalidDuration.selector);
        lbHooksExtra.setRewarderParameters(maxRewardPerSecond, startTimestamp, 0);

        vm.expectRevert(ILBHooksBaseSimpleRewarder.LBHooksBaseSimpleRewarder__InvalidDuration.selector);
        lbHooksExtra.setRewarderParameters(0, startTimestamp, expectedDuration);

        vm.expectRevert(ILBHooksBaseSimpleRewarder.LBHooksBaseSimpleRewarder__ZeroReward.selector);
        lbHooksExtra.setRewarderParameters(maxRewardPerSecond, startTimestamp, expectedDuration);

        MockERC20(address(rewardToken01)).mint(address(lbHooksExtra), maxRewardPerSecond * expectedDuration);

        assertEq(
            lbHooksExtra.setRewarderParameters(maxRewardPerSecond, startTimestamp, expectedDuration),
            maxRewardPerSecond,
            "test_fuzz_SetRewardsParameters::1"
        );

        (uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp) =
            lbHooksExtra.getRewarderParameter();

        assertEq(rewardPerSecond, maxRewardPerSecond, "test_fuzz_SetRewardsParameters::2");
        assertEq(lastUpdateTimestamp, startTimestamp, "test_fuzz_SetRewardsParameters::3");
        assertEq(endTimestamp, startTimestamp + expectedDuration, "test_fuzz_SetRewardsParameters::4");

        assertEq(
            lbHooksExtra.setRewarderParameters(maxRewardPerSecond, block.timestamp, expectedDuration),
            maxRewardPerSecond,
            "test_fuzz_SetRewardsParameters::5"
        );

        (rewardPerSecond, lastUpdateTimestamp, endTimestamp) = lbHooksExtra.getRewarderParameter();

        assertEq(rewardPerSecond, maxRewardPerSecond, "test_fuzz_SetRewardsParameters::6");
        assertEq(lastUpdateTimestamp, block.timestamp, "test_fuzz_SetRewardsParameters::7");
        assertEq(endTimestamp, block.timestamp + expectedDuration, "test_fuzz_SetRewardsParameters::8");

        assertEq(
            lbHooksExtra.setRewardPerSecond(maxRewardPerSecond, expectedDuration),
            maxRewardPerSecond,
            "test_fuzz_SetRewardsParameters::9"
        );

        (rewardPerSecond, lastUpdateTimestamp, endTimestamp) = lbHooksExtra.getRewarderParameter();

        assertEq(rewardPerSecond, maxRewardPerSecond, "test_fuzz_SetRewardsParameters::10");
        assertEq(lastUpdateTimestamp, block.timestamp, "test_fuzz_SetRewardsParameters::11");
        assertEq(endTimestamp, block.timestamp + expectedDuration, "test_fuzz_SetRewardsParameters::12");

        vm.prank(address(lbHooksManager));
        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        assertFalse(lbHooksExtra.isLinked(), "test_fuzz_SetRewardsParameters::13");

        vm.expectRevert(ILBHooksBaseSimpleRewarder.LBHooksBaseSimpleRewarder__Stopped.selector);
        lbHooksExtra.setRewarderParameters(maxRewardPerSecond, startTimestamp, expectedDuration);

        vm.prank(address(lbHooksManager));
        lbHooks.setLBHooksExtraRewarder(address(0), new bytes(0));

        assertFalse(lbHooksExtra.isLinked(), "test_fuzz_SetRewardsParameters::14");

        vm.expectRevert(ILBHooksBaseSimpleRewarder.LBHooksBaseSimpleRewarder__Stopped.selector);
        lbHooksExtra.setRewarderParameters(maxRewardPerSecond, startTimestamp, expectedDuration);
    }
}

contract MockExtraHook {
    address public getLBPair;
    address public getParentRewarder;

    function setLBPair(address lbPair) public {
        getLBPair = lbPair;
    }

    function setParentRewarder(address parentRewarder) public {
        getParentRewarder = parentRewarder;
    }
}
