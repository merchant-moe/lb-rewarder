// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./TestHelper.sol";

import "../src/LBHooksBaseRewarder.sol";
import "../src/LBHooksBaseSimpleRewarder.sol";
import "../src/LBHooksSimpleRewarder.sol";
import "../src/LBHooksExtraRewarder.sol";

contract LBHooksSimpleRewarderTest is TestHelper {
    LBHooksSimpleRewarder lbHooks;
    LBHooksExtraRewarder lbHooksExtra;

    function setUp() public override {
        super.setUp();

        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.SimpleRewarder,
            Hooks.setHooks(hooksParameters, address(new LBHooksSimpleRewarder(address(lbHooksManager))))
        );
        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.ExtraRewarder,
            Hooks.setHooks(hooksParameters, address(new LBHooksExtraRewarder(address(lbHooksManager))))
        );

        lbHooks = LBHooksSimpleRewarder(
            payable(
                address(
                    lbHooksManager.createLBHooksSimpleRewarder(
                        IERC20(address(token0)),
                        IERC20(address(token1)),
                        DEFAULT_BIN_STEP,
                        IERC20(address(rewardToken01)),
                        address(this)
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
                        IERC20(address(rewardToken02)),
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
        assertEq(address(lbHooks.getLBHooksManager()), address(lbHooksManager), "test_Getters::1");
        assertEq(address(lbHooksExtra.getParentRewarder()), address(lbHooks), "test_Getters::2");

        (uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp) = lbHooks.getRewarderParameter();

        assertEq(rewardPerSecond, 0, "test_Getters::3");
        assertEq(lastUpdateTimestamp, 0, "test_Getters::4");
        assertEq(endTimestamp, 0, "test_Getters::5");

        assertEq(lbHooks.getRemainingRewards(), 0, "test_Getters::6");
    }

    function test_GetPendingRewardSwapAndTransfer() public {
        MockERC20(address(rewardToken01)).mint(address(lbHooks), 400e18);
        lbHooks.setDeltaBins(-1, 2);
        lbHooks.setRewardPerSecond(2e18, 200);

        MockERC20(address(rewardToken02)).mint(address(lbHooksExtra), 100e18);
        lbHooksExtra.setDeltaBins(0, 1);
        lbHooksExtra.setRewardPerSecond(1e18, 100);

        _addLiquidity(pair01, alice, DEFAULT_ID, 1, 10e18, 10e18);
        _addLiquidity(pair01, bob, DEFAULT_ID, 0, 30e18, 30e18);

        assertEq(lbHooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::1");
        assertEq(lbHooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::2");

        vm.warp(block.timestamp + 1);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 1e18, 1e14, "test_GetPendingRewardSwapAndTransfer::3");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 1e18, 1e14, "test_GetPendingRewardSwapAndTransfer::4");
        assertApproxEqRel(lbHooks.getRemainingRewards(), 398e18, 1e14, "test_GetPendingRewardSwapAndTransfer::5");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::6"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::7"
        );
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 99e18, 1e14, "test_GetPendingRewardSwapAndTransfer::8");

        _swap(pair01, address(this), 1e18, 0);

        assertApproxEqRel(lbHooks.getRemainingRewards(), 398e18, 1e14, "test_GetPendingRewardSwapAndTransfer::9");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 99e18, 1e14, "test_GetPendingRewardSwapAndTransfer::10");

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 1e18, 1e14, "test_GetPendingRewardSwapAndTransfer::11");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 1e18, 1e14, "test_GetPendingRewardSwapAndTransfer::12");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::13"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::14"
        );

        _swap(pair01, address(this), 0, 1e18);

        assertApproxEqRel(lbHooks.getRemainingRewards(), 398e18, 1e14, "test_GetPendingRewardSwapAndTransfer::15");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 99e18, 1e14, "test_GetPendingRewardSwapAndTransfer::16");

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 1e18, 1e14, "test_GetPendingRewardSwapAndTransfer::17");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 1e18, 1e14, "test_GetPendingRewardSwapAndTransfer::18");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::19"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::20"
        );

        vm.warp(block.timestamp + 9);

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 10e18, 1e14, "test_GetPendingRewardSwapAndTransfer::21"
        );
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 10e18, 1e14, "test_GetPendingRewardSwapAndTransfer::22");
        assertApproxEqRel(lbHooks.getRemainingRewards(), 380e18, 1e14, "test_GetPendingRewardSwapAndTransfer::23");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 2.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::24"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::25"
        );
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 90e18, 1e14, "test_GetPendingRewardSwapAndTransfer::26");

        lbHooks.setDeltaBins(0, 1);

        assertApproxEqRel(lbHooks.getRemainingRewards(), 380e18, 1e14, "test_GetPendingRewardSwapAndTransfer::27");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 90e18, 1e14, "test_GetPendingRewardSwapAndTransfer::28");

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 10e18, 1e14, "test_GetPendingRewardSwapAndTransfer::29"
        );
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 10e18, 1e14, "test_GetPendingRewardSwapAndTransfer::30");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 2.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::31"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::32"
        );

        vm.warp(block.timestamp + 1);

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 10.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::33"
        );
        assertApproxEqRel(
            lbHooks.getPendingRewards(bob, ids), 11.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::34"
        );
        assertApproxEqRel(lbHooks.getRemainingRewards(), 378e18, 1e14, "test_GetPendingRewardSwapAndTransfer::35");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 2.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::36"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 8.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::37"
        );
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 89e18, 1e14, "test_GetPendingRewardSwapAndTransfer::38");

        vm.prank(bob);
        pair01.batchTransferFrom(bob, alice, ids, new uint256[](ids.length));

        assertApproxEqRel(lbHooks.getRemainingRewards(), 378e18, 1e14, "test_GetPendingRewardSwapAndTransfer::39");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 89e18, 1e14, "test_GetPendingRewardSwapAndTransfer::40");

        assertApproxEqRel(
            lbHooks.getPendingRewards(alice, ids), 10.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::41"
        );
        assertApproxEqRel(
            lbHooks.getPendingRewards(bob, ids), 11.5e18, 1e15, "test_GetPendingRewardSwapAndTransfer::42"
        );

        assertEq(rewardToken01.balanceOf(alice), 0, "test_GetPendingRewardSwapAndTransfer::43");
        assertEq(rewardToken01.balanceOf(bob), 0, "test_GetPendingRewardSwapAndTransfer::44");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 2.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::45"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 8.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::46"
        );

        assertEq(rewardToken02.balanceOf(alice), 0, "test_GetPendingRewardSwapAndTransfer::47");
        assertEq(rewardToken02.balanceOf(bob), 0, "test_GetPendingRewardSwapAndTransfer::48");

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        assertEq(lbHooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::49");
        assertApproxEqRel(
            lbHooks.getPendingRewards(bob, ids), 11.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::50"
        );
        assertApproxEqRel(rewardToken01.balanceOf(alice), 10.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::51");

        assertEq(lbHooksExtra.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::52");
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 8.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::53"
        );
        assertApproxEqRel(rewardToken02.balanceOf(alice), 2.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::54");

        vm.warp(block.timestamp + 10);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__UnauthorizedCaller.selector);
        lbHooksExtra.claim(address(this), ids);

        lbHooks.setLBHooksExtraRewarder(address(0), new bytes(0));

        assertFalse(lbHooksExtra.isLinked(), "test_GetPendingRewardSwapAndTransfer::55");

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::56");
        assertApproxEqRel(
            lbHooks.getPendingRewards(bob, ids), 26.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::57"
        );
        assertApproxEqRel(lbHooks.getRemainingRewards(), 358e18, 1e14, "test_GetPendingRewardSwapAndTransfer::58");

        assertEq(lbHooksExtra.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::59");
        assertEq(lbHooksExtra.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::60");

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        assertEq(lbHooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::61");
        assertApproxEqRel(
            lbHooks.getPendingRewards(bob, ids), 26.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::62"
        );
        assertApproxEqRel(rewardToken01.balanceOf(alice), 15.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::63");

        assertEq(lbHooksExtra.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::64");
        assertEq(lbHooksExtra.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::65");

        vm.prank(address(lbHooksManager));
        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__UnlinkedHooks.selector);
        lbHooks.claim(address(this), ids);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__UnlinkedHooks.selector);
        lbHooksExtra.claim(address(this), ids);

        assertEq(lbHooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::66");
        assertEq(lbHooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::67");

        assertEq(lbHooksExtra.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::68");
        assertEq(lbHooksExtra.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::69");
    }

    function test_GetPendingRewardMintAndBurn() public {
        MockERC20(address(rewardToken01)).mint(address(lbHooks), 400e18);
        lbHooks.setDeltaBins(-1, 2);
        lbHooks.setRewardPerSecond(2e18, 200);

        MockERC20(address(rewardToken02)).mint(address(lbHooksExtra), 100e18);
        lbHooksExtra.setDeltaBins(0, 1);
        lbHooksExtra.setRewardPerSecond(1e18, 100);

        vm.warp(block.timestamp + 1);

        _addLiquidity(pair01, alice, DEFAULT_ID, 1, 10e18, 10e18);
        _addLiquidity(pair01, bob, DEFAULT_ID, 0, 30e18, 30e18);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 0, 1e14, "test_GetPendingRewardMintAndBurn::1");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 0, 1e14, "test_GetPendingRewardMintAndBurn::2");

        assertApproxEqRel(lbHooksExtra.getPendingRewards(alice, ids), 0, 1e14, "test_GetPendingRewardMintAndBurn::3");
        assertApproxEqRel(lbHooksExtra.getPendingRewards(bob, ids), 0, 1e14, "test_GetPendingRewardMintAndBurn::4");

        vm.warp(block.timestamp + 4);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 4e18, 1e14, "test_GetPendingRewardMintAndBurn::5");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 4e18, 1e14, "test_GetPendingRewardMintAndBurn::6");
        assertApproxEqRel(lbHooks.getRemainingRewards(), 392e18, 1e14, "test_GetPendingRewardMintAndBurn::7");

        assertApproxEqRel(lbHooksExtra.getPendingRewards(alice, ids), 1e18, 1e14, "test_GetPendingRewardMintAndBurn::8");
        assertApproxEqRel(lbHooksExtra.getPendingRewards(bob, ids), 3e18, 1e14, "test_GetPendingRewardMintAndBurn::9");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 96e18, 1e14, "test_GetPendingRewardMintAndBurn::10");

        vm.warp(block.timestamp + 4);

        _removeLiquidity(pair01, bob, DEFAULT_ID, 0, uint256(2e18) / 3);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 8e18, 1e14, "test_GetPendingRewardMintAndBurn::11");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 8e18, 1e14, "test_GetPendingRewardMintAndBurn::12");
        assertApproxEqRel(lbHooks.getRemainingRewards(), 384e18, 1e14, "test_GetPendingRewardMintAndBurn::13");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 2e18, 1e14, "test_GetPendingRewardMintAndBurn::14"
        );
        assertApproxEqRel(lbHooksExtra.getPendingRewards(bob, ids), 6e18, 1e14, "test_GetPendingRewardMintAndBurn::15");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 92e18, 1e14, "test_GetPendingRewardMintAndBurn::16");

        assertEq(rewardToken01.balanceOf(bob), 0, "test_GetPendingRewardMintAndBurn::17");
        assertEq(rewardToken02.balanceOf(bob), 0, "test_GetPendingRewardMintAndBurn::18");

        vm.warp(block.timestamp + 4);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 14e18, 1e14, "test_GetPendingRewardMintAndBurn::19");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 10e18, 1e14, "test_GetPendingRewardMintAndBurn::20");
        assertApproxEqRel(lbHooks.getRemainingRewards(), 376e18, 1e14, "test_GetPendingRewardMintAndBurn::21");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 4e18, 1e14, "test_GetPendingRewardMintAndBurn::22"
        );
        assertApproxEqRel(lbHooksExtra.getPendingRewards(bob, ids), 8e18, 1e14, "test_GetPendingRewardMintAndBurn::23");
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 88e18, 1e14, "test_GetPendingRewardMintAndBurn::24");

        vm.warp(block.timestamp + 87);

        assertApproxEqRel(lbHooks.getPendingRewards(alice, ids), 144.5e18, 1e14, "test_GetPendingRewardMintAndBurn::25");
        assertApproxEqRel(lbHooks.getPendingRewards(bob, ids), 53.5e18, 1e14, "test_GetPendingRewardMintAndBurn::26");
        assertApproxEqRel(lbHooks.getRemainingRewards(), 202e18, 1e14, "test_GetPendingRewardMintAndBurn::27");

        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(bob, ids), 51.5e18, 1e14, "test_GetPendingRewardMintAndBurn::28"
        );
        assertApproxEqRel(
            lbHooksExtra.getPendingRewards(alice, ids), 47.5e18, 1e14, "test_GetPendingRewardMintAndBurn::29"
        );
        assertApproxEqRel(lbHooksExtra.getRemainingRewards(), 1e18, 1e14, "test_GetPendingRewardMintAndBurn::30");

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        vm.prank(bob);
        lbHooks.claim(bob, ids);

        assertApproxEqRel(rewardToken01.balanceOf(alice), 144.5e18, 1e14, "test_GetPendingRewardMintAndBurn::31");
        assertApproxEqRel(rewardToken01.balanceOf(bob), 53.5e18, 1e14, "test_GetPendingRewardMintAndBurn::32");

        assertApproxEqRel(rewardToken02.balanceOf(alice), 47.5e18, 1e14, "test_GetPendingRewardMintAndBurn::33");
        assertApproxEqRel(rewardToken02.balanceOf(bob), 51.5e18, 1e14, "test_GetPendingRewardMintAndBurn::34");

        vm.warp(block.timestamp + 1);

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        vm.prank(bob);
        lbHooks.claim(bob, ids);

        assertApproxEqRel(rewardToken01.balanceOf(alice), 146e18, 1e14, "test_GetPendingRewardMintAndBurn::35");
        assertApproxEqRel(rewardToken01.balanceOf(bob), 54e18, 1e14, "test_GetPendingRewardMintAndBurn::36");

        assertApproxEqRel(rewardToken02.balanceOf(alice), 47.5e18, 1e14, "test_GetPendingRewardMintAndBurn::37");
        assertApproxEqRel(rewardToken02.balanceOf(bob), 51.5e18, 1e14, "test_GetPendingRewardMintAndBurn::38");

        vm.warp(block.timestamp + 199);

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        vm.prank(bob);
        lbHooks.claim(bob, ids);

        assertApproxEqRel(rewardToken01.balanceOf(alice), 294.5e18, 1e14, "test_GetPendingRewardMintAndBurn::39");
        assertApproxEqRel(rewardToken01.balanceOf(bob), 103.5e18, 1e14, "test_GetPendingRewardMintAndBurn::40");

        assertApproxEqRel(rewardToken02.balanceOf(alice), 47.5e18, 1e14, "test_GetPendingRewardMintAndBurn::41");
        assertApproxEqRel(rewardToken02.balanceOf(bob), 51.5e18, 1e14, "test_GetPendingRewardMintAndBurn::42");

        vm.warp(block.timestamp + 1);

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        vm.prank(bob);
        lbHooks.claim(bob, ids);

        assertApproxEqRel(rewardToken01.balanceOf(alice), 294.5e18, 1e14, "test_GetPendingRewardMintAndBurn::43");
        assertApproxEqRel(rewardToken01.balanceOf(bob), 103.5e18, 1e14, "test_GetPendingRewardMintAndBurn::44");

        assertApproxEqRel(rewardToken02.balanceOf(alice), 47.5e18, 1e14, "test_GetPendingRewardMintAndBurn::45");
        assertApproxEqRel(rewardToken02.balanceOf(bob), 51.5e18, 1e14, "test_GetPendingRewardMintAndBurn::46");

        vm.warp(block.timestamp + 1);

        vm.prank(alice);
        lbHooks.claim(alice, ids);

        vm.prank(bob);
        lbHooks.claim(bob, ids);

        assertApproxEqRel(rewardToken01.balanceOf(alice), 294.5e18, 1e14, "test_GetPendingRewardMintAndBurn::47");
        assertApproxEqRel(rewardToken01.balanceOf(bob), 103.5e18, 1e14, "test_GetPendingRewardMintAndBurn::48");

        assertApproxEqRel(rewardToken02.balanceOf(alice), 47.5e18, 1e14, "test_GetPendingRewardMintAndBurn::49");
        assertApproxEqRel(rewardToken02.balanceOf(bob), 51.5e18, 1e14, "test_GetPendingRewardMintAndBurn::50");
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
        lbHooks.setRewarderParameters(maxRewardPerSecond, startTimestamp, expectedDuration);

        startTimestamp = bound(startTimestamp, block.timestamp, type(uint256).max);

        expectedDuration = bound(expectedDuration, 1, type(uint256).max - startTimestamp);
        maxRewardPerSecond = bound(maxRewardPerSecond, 1, type(uint256).max / expectedDuration);

        vm.expectRevert(ILBHooksBaseSimpleRewarder.LBHooksBaseSimpleRewarder__InvalidDuration.selector);
        lbHooks.setRewarderParameters(maxRewardPerSecond, startTimestamp, 0);

        vm.expectRevert(ILBHooksBaseSimpleRewarder.LBHooksBaseSimpleRewarder__InvalidDuration.selector);
        lbHooks.setRewarderParameters(0, startTimestamp, expectedDuration);

        vm.expectRevert(ILBHooksBaseSimpleRewarder.LBHooksBaseSimpleRewarder__ZeroReward.selector);
        lbHooks.setRewarderParameters(maxRewardPerSecond, startTimestamp, expectedDuration);

        MockERC20(address(rewardToken01)).mint(address(lbHooks), maxRewardPerSecond * expectedDuration);

        assertEq(
            lbHooks.setRewarderParameters(maxRewardPerSecond, startTimestamp, expectedDuration),
            maxRewardPerSecond,
            "test_fuzz_SetRewardsParameters::1"
        );

        (uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp) = lbHooks.getRewarderParameter();

        assertEq(rewardPerSecond, maxRewardPerSecond, "test_fuzz_SetRewardsParameters::2");
        assertEq(lastUpdateTimestamp, startTimestamp, "test_fuzz_SetRewardsParameters::3");
        assertEq(endTimestamp, startTimestamp + expectedDuration, "test_fuzz_SetRewardsParameters::4");

        assertEq(
            lbHooks.setRewarderParameters(maxRewardPerSecond, block.timestamp, expectedDuration),
            maxRewardPerSecond,
            "test_fuzz_SetRewardsParameters::5"
        );

        (rewardPerSecond, lastUpdateTimestamp, endTimestamp) = lbHooks.getRewarderParameter();

        assertEq(rewardPerSecond, maxRewardPerSecond, "test_fuzz_SetRewardsParameters::6");
        assertEq(lastUpdateTimestamp, block.timestamp, "test_fuzz_SetRewardsParameters::7");
        assertEq(endTimestamp, block.timestamp + expectedDuration, "test_fuzz_SetRewardsParameters::8");

        assertEq(
            lbHooks.setRewardPerSecond(maxRewardPerSecond, expectedDuration),
            maxRewardPerSecond,
            "test_fuzz_SetRewardsParameters::9"
        );

        (rewardPerSecond, lastUpdateTimestamp, endTimestamp) = lbHooks.getRewarderParameter();

        assertEq(rewardPerSecond, maxRewardPerSecond, "test_fuzz_SetRewardsParameters::10");
        assertEq(lastUpdateTimestamp, block.timestamp, "test_fuzz_SetRewardsParameters::11");
        assertEq(endTimestamp, block.timestamp + expectedDuration, "test_fuzz_SetRewardsParameters::12");

        vm.prank(address(lbHooksManager));
        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        assertFalse(lbHooks.isLinked(), "test_fuzz_SetRewardsParameters::13");

        vm.expectRevert(ILBHooksBaseSimpleRewarder.LBHooksBaseSimpleRewarder__Stopped.selector);
        lbHooks.setRewarderParameters(maxRewardPerSecond, startTimestamp, expectedDuration);

        vm.prank(address(lbHooksManager));
        lbHooks.setLBHooksExtraRewarder(address(0), new bytes(0));

        assertFalse(lbHooks.isLinked(), "test_fuzz_SetRewardsParameters::14");

        vm.expectRevert(ILBHooksBaseSimpleRewarder.LBHooksBaseSimpleRewarder__Stopped.selector);
        lbHooks.setRewarderParameters(maxRewardPerSecond, startTimestamp, expectedDuration);
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
