// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {TestHelper} from "./TestHelper.sol";

import "./mocks/MockERC20.sol";
import "../src/LBHooksBaseRewarder.sol";

contract LBHooksBaseRewarderTest is TestHelper {
    MockLBHooksRewarder hooks;

    function setUp() public override {
        super.setUp();

        factory.grantRole(factory.LB_HOOKS_MANAGER_ROLE(), address(this));

        hooksParameters = Hooks.setHooks(hooksParameters, address(new MockLBHooksRewarder()));

        hooks = MockLBHooksRewarder(
            payable(
                _createAndSetLBHooks(
                    pair01,
                    hooksParameters,
                    abi.encodePacked(address(pair01), address(rewardToken01)),
                    abi.encode(address(this))
                )
            )
        );

        vm.label(address(hooks), "hooks");
    }

    function test_Getters() public {
        assertEq(address(hooks.getLBPair()), address(pair01), "test_Getters::1");
        assertEq(address(hooks.getRewardToken()), address(rewardToken01), "test_Getters::2");
        assertFalse(hooks.isStopped(), "test_Getters::3");

        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        assertTrue(hooks.isStopped(), "test_Getters::4");
    }

    function test_GetPendingRewardSwapAndTransfer() public {
        hooks.setDeltaBins(-1, 2);

        _addLiquidity(pair01, alice, DEFAULT_ID, 2, 10e18, 10e18);
        _addLiquidity(pair01, bob, DEFAULT_ID, 1, 30e18, 30e18);

        assertEq(hooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::1");
        assertEq(hooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::2");

        vm.warp(block.timestamp + 1);

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::3");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::4");

        _swap(pair01, address(this), 1e18, 0);
        assertEq(rewardToken01.balanceOf(address(hooks)), 1e18, "test_GetPendingRewardSwapAndTransfer::5");

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::6");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::7");

        _swap(pair01, address(this), 0, 1e18);
        assertEq(rewardToken01.balanceOf(address(hooks)), 1e18, "test_GetPendingRewardSwapAndTransfer::8");

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 0.25e18, 1e14, "test_GetPendingRewardSwapAndTransfer::9");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 0.75e18, 1e14, "test_GetPendingRewardSwapAndTransfer::10");

        vm.warp(block.timestamp + 9);

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 2.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::11");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::12");

        hooks.setDeltaBins(-2, -1);

        assertEq(rewardToken01.balanceOf(address(hooks)), 10e18, "test_GetPendingRewardSwapAndTransfer::13");

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 2.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::14");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::15");

        vm.warp(block.timestamp + 1);

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 3.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::16");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::17");

        vm.prank(bob);
        pair01.batchTransferFrom(bob, alice, ids, new uint256[](ids.length));

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 3.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::18");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::19");
        assertEq(rewardToken01.balanceOf(bob), 0, "test_GetPendingRewardSwapAndTransfer::20");

        vm.prank(alice);
        hooks.claim(alice, ids);

        assertEq(hooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::21");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::22");
        assertApproxEqRel(rewardToken01.balanceOf(alice), 3.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::23");

        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__UnlinkedHooks.selector);
        hooks.claim(address(this), ids);
    }

    function test_GetPendingRewardMintAndBurn() public {
        hooks.setDeltaBins(-1, 2);

        vm.warp(block.timestamp + 1);

        _addLiquidity(pair01, alice, DEFAULT_ID, 2, 10e18, 10e18);

        assertEq(rewardToken01.balanceOf(address(hooks)), 1e18, "test_GetPendingRewardMintAndBurn::1");

        _addLiquidity(pair01, bob, DEFAULT_ID, 1, 30e18, 30e18);

        assertEq(rewardToken01.balanceOf(address(hooks)), 1e18, "test_GetPendingRewardMintAndBurn::2");

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 1e18, 1e14, "test_GetPendingRewardMintAndBurn::3");

        vm.warp(block.timestamp + 4);

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 2e18, 1e14, "test_GetPendingRewardMintAndBurn::4");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 3e18, 1e14, "test_GetPendingRewardMintAndBurn::5");

        vm.warp(block.timestamp + 4);

        _removeLiquidity(pair01, bob, DEFAULT_ID, 1, uint256(2e18) / 3);

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 3e18, 1e14, "test_GetPendingRewardMintAndBurn::6");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 6e18, 1e14, "test_GetPendingRewardMintAndBurn::7");
        assertEq(rewardToken01.balanceOf(bob), 0, "test_GetPendingRewardMintAndBurn::8");

        vm.warp(block.timestamp + 4);

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 5e18, 1e14, "test_GetPendingRewardMintAndBurn::9");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 8e18, 1e14, "test_GetPendingRewardMintAndBurn::10");

        uint256[] memory edgeIds = new uint256[](4);

        edgeIds[0] = DEFAULT_ID - 201;
        edgeIds[1] = DEFAULT_ID - 200;
        edgeIds[2] = DEFAULT_ID + 200;
        edgeIds[3] = DEFAULT_ID + 201;

        // 6e18 is from the cached reward
        assertApproxEqRel(hooks.getPendingRewards(bob, edgeIds), 6e18, 1e14, "test_GetPendingRewardMintAndBurn::11");

        hooks.setDeltaBins(-200, -200 + 1);

        // 6e18 is from the cached reward
        assertApproxEqRel(hooks.getPendingRewards(bob, edgeIds), 6e18, 1e14, "test_GetPendingRewardMintAndBurn::12");

        vm.warp(block.timestamp + 4);

        // Try to claim the same bin more than once
        ids.push(DEFAULT_ID);
        ids.push(DEFAULT_ID);

        vm.prank(bob);
        hooks.claim(bob, ids);

        assertEq(hooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardMintAndBurn::13");
        assertApproxEqRel(rewardToken01.balanceOf(bob), 8e18, 1e14, "test_GetPendingRewardMintAndBurn::14");

        vm.warp(block.timestamp + 4);

        ids.pop();
        ids.pop(); // remove the duplicate

        ids.push(DEFAULT_ID - 200);

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 5e18, 1e14, "test_GetPendingRewardMintAndBurn::15");
        assertEq(hooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardMintAndBurn::16");

        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        assertEq(hooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardMintAndBurn::17");
    }

    function test_SendNative(bytes memory data) public {
        vm.assume(data.length > 0);

        (bool s, bytes memory d) = address(hooks).call{value: 0}("");
        assertFalse(s, "test_SendNative::1");
        assertEq(
            keccak256(d),
            keccak256(abi.encodeWithSelector(ILBHooksBaseRewarder.LBHooksBaseRewarder__NotNativeRewarder.selector)),
            "test_SendNative::2"
        );

        hooks = MockLBHooksRewarder(
            payable(
                _createAndSetLBHooks(
                    pair01, hooksParameters, abi.encodePacked(pair01, address(0)), abi.encode(address(this))
                )
            )
        );

        (s, d) = address(hooks).call{value: 1e18}(data);
        assertFalse(s, "test_SendNative::3");
        assertEq(
            keccak256(d),
            keccak256(abi.encodeWithSelector(ILBHooksBaseRewarder.LBHooksBaseRewarder__NotImplemented.selector)),
            "test_SendNative::4"
        );

        (s, d) = address(hooks).call{value: 1e18}("");
        assertTrue(s, "test_SendNative::5");
        assertEq(d.length, 0, "test_SendNative::6");
    }

    function test_NativeReward() public {
        hooks = MockLBHooksRewarder(
            payable(
                _createAndSetLBHooks(
                    pair01, hooksParameters, abi.encodePacked(pair01, address(0)), abi.encode(address(this))
                )
            )
        );

        deal(address(hooks), 1e18);

        hooks.give(alice, 1e18);

        assertEq(hooks.getPendingRewards(alice, ids), 1e18, "test_NativeReward::1");
        assertEq(alice.balance, 0, "test_NativeReward::2");

        vm.prank(alice);
        hooks.claim(alice, ids);

        assertEq(hooks.getPendingRewards(alice, ids), 0, "test_NativeReward::3");
        assertEq(alice.balance, 1e18, "test_NativeReward::4");
    }

    function test_Sweep() public {
        MockERC20(address(token0)).mint(address(hooks), 1e18);
        hooks.sweep(IERC20(address(token0)), alice);

        assertEq(token0.balanceOf(alice), 1e18, "test_Sweep::1");

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__ZeroBalance.selector);
        hooks.sweep(IERC20(address(token0)), alice);

        deal(address(hooks), 1e18);

        hooks.sweep(IERC20(address(0)), alice);

        assertEq(alice.balance, 1e18, "test_Sweep::2");

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__ZeroBalance.selector);
        hooks.sweep(IERC20(address(token0)), alice);

        MockERC20(address(rewardToken01)).mint(address(hooks), 1e18);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__LockedRewardToken.selector);
        hooks.sweep(IERC20(address(rewardToken01)), alice);

        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        hooks.sweep(IERC20(address(rewardToken01)), alice);

        assertEq(rewardToken01.balanceOf(alice), 1e18, "test_Sweep::3");
    }

    function test_fuzz_SetDeltaBins(int24 deltaBinA, int24 deltaBinB) public {
        deltaBinA = int24(bound(deltaBinA, type(int24).min + 1, type(int24).max));
        deltaBinB = int24(bound(deltaBinB, type(int24).min, deltaBinA - 1));

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__InvalidDeltaBins.selector);
        hooks.setDeltaBins(deltaBinA, deltaBinB);

        deltaBinA = int24(bound(deltaBinA, type(int24).min, type(int24).max - 11 - 1));
        deltaBinB = int24(bound(deltaBinB, deltaBinA + 11 + 1, type(int24).max));

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__ExceedsMaxNumberOfBins.selector);
        hooks.setDeltaBins(deltaBinA, deltaBinB);
    }
}

contract MockLBHooksRewarder is LBHooksBaseRewarder {
    uint256 private _lastTimestamp;

    constructor() LBHooksBaseRewarder(address(0)) {}

    function give(address account, uint256 amount) public {
        _totalUnclaimedRewards += amount;
        _unclaimedRewards[account] += amount;
    }

    function _onHooksSet(bytes calldata) internal override {
        _lastTimestamp = block.timestamp;
    }

    function _updateRewards() internal override returns (uint256) {
        uint256 lastTimestamp = _lastTimestamp;

        if (block.timestamp > lastTimestamp) {
            unchecked {
                uint256 amount = (block.timestamp - lastTimestamp) * 1e18;
                MockERC20(address(_getRewardToken())).mint(address(this), amount);
            }

            _lastTimestamp = block.timestamp;
        }

        return _balanceOfThis(_getRewardToken()) - _totalUnclaimedRewards;
    }

    function _getPendingTotalRewards() internal view override returns (uint256 pendingTotalRewards) {
        uint256 lastTimestamp = _lastTimestamp;

        if (block.timestamp > lastTimestamp) {
            unchecked {
                pendingTotalRewards = (block.timestamp - lastTimestamp) * 1e18;
            }
        }
    }
}
