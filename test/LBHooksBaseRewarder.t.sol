// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {TestHelper} from "./TestHelper.sol";

import "./mocks/MockERC20.sol";
import "../src/LBHooksBaseRewarder.sol";

contract LBHooksBaseRewarderTest is TestHelper {
    MockLBHooksBaseRewarder hooks;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint24 activeId;
    uint256[] ids;

    function setUp() public override {
        super.setUp();

        address hookImplementation = address(new MockLBHooksBaseRewarder());

        factory.setDefaultLBHooksParameters(
            Hooks.Parameters({
                hooks: hookImplementation,
                beforeSwap: true,
                afterSwap: false,
                beforeFlashLoan: false,
                afterFlashLoan: false,
                beforeMint: true,
                afterMint: true,
                beforeBurn: true,
                afterBurn: true,
                beforeBatchTransferFrom: true,
                afterBatchTransferFrom: true
            })
        );

        hooks = MockLBHooksBaseRewarder(
            payable(
                address(
                    factory.createDefaultLBHooksOnPair(
                        token0, token1, DEFAULT_BIN_STEP, abi.encodePacked(rewardToken01), abi.encode(address(this))
                    )
                )
            )
        );

        vm.label(address(hooks), "hooks");

        ids.push(DEFAULT_ID - 2);
        ids.push(DEFAULT_ID - 1);
        ids.push(DEFAULT_ID);
        ids.push(DEFAULT_ID + 1);
        ids.push(DEFAULT_ID + 2);
    }

    function test_Getters() public {
        assertEq(address(hooks.getLBPair()), address(pair01), "test_Getters::1");
        assertEq(address(hooks.getRewardToken()), address(rewardToken01), "test_Getters::2");
        assertFalse(hooks.isStopped(), "test_Getters::3");

        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        assertTrue(hooks.isStopped(), "test_Getters::4");
    }

    function test_GetPendingRewardSwapAndTransfer() public {
        _addLiquidity(pair01, alice, DEFAULT_ID, 2, 10e18, 10e18);
        _addLiquidity(pair01, bob, DEFAULT_ID, 1, 30e18, 30e18);

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
        assertEq(hooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::19");
        assertApproxEqRel(rewardToken01.balanceOf(bob), 7.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::20");

        vm.prank(alice);
        hooks.claim(ids);

        assertEq(hooks.getPendingRewards(alice, ids), 0, "test_GetPendingRewardSwapAndTransfer::21");
        assertEq(hooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardSwapAndTransfer::22");
        assertApproxEqRel(rewardToken01.balanceOf(alice), 3.5e18, 1e14, "test_GetPendingRewardSwapAndTransfer::23");

        factory.removeLBHooksOnPair(token0, token1, DEFAULT_BIN_STEP);

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__UnlinkedHooks.selector);
        hooks.claim(ids);
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
        assertEq(hooks.getPendingRewards(bob, ids), 0, "test_GetPendingRewardMintAndBurn::7");
        assertApproxEqRel(rewardToken01.balanceOf(bob), 6e18, 1e14, "test_GetPendingRewardMintAndBurn::8");

        vm.warp(block.timestamp + 4);

        assertApproxEqRel(hooks.getPendingRewards(alice, ids), 5e18, 1e14, "test_GetPendingRewardMintAndBurn::9");
        assertApproxEqRel(hooks.getPendingRewards(bob, ids), 2e18, 1e14, "test_GetPendingRewardMintAndBurn::10");
        assertApproxEqRel(rewardToken01.balanceOf(bob), 6e18, 1e14, "test_GetPendingRewardMintAndBurn::11");
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

        hooks = MockLBHooksBaseRewarder(
            payable(
                address(
                    factory.createDefaultLBHooksOnPair(
                        token0, token1, DEFAULT_BIN_STEP, abi.encodePacked(address(0)), abi.encode(address(this))
                    )
                )
            )
        );

        (s, d) = address(hooks).call{value: 0}("");
        assertFalse(s, "test_SendNative::3");
        assertEq(
            keccak256(d),
            keccak256(abi.encodeWithSelector(ILBHooksBaseRewarder.LBHooksBaseRewarder__NoValueReceived.selector)),
            "test_SendNative::4"
        );

        (s, d) = address(hooks).call{value: 1e18}(data);
        assertFalse(s, "test_SendNative::5");
        assertEq(
            keccak256(d),
            keccak256(abi.encodeWithSelector(ILBHooksBaseRewarder.LBHooksBaseRewarder__NotImplemented.selector)),
            "test_SendNative::6"
        );

        (s, d) = address(hooks).call{value: 1e18}("");
        assertTrue(s, "test_SendNative::7");
        assertEq(d.length, 0, "test_SendNative::8");
    }

    function test_NativeReward() public {
        hooks = MockLBHooksBaseRewarder(
            payable(
                address(
                    factory.createDefaultLBHooksOnPair(
                        token0, token1, DEFAULT_BIN_STEP, abi.encodePacked(address(0)), abi.encode(address(this))
                    )
                )
            )
        );

        deal(address(hooks), 1e18);

        hooks.give(alice, 1e18);

        assertEq(hooks.getPendingRewards(alice, ids), 1e18, "test_NativeReward::1");
        assertEq(alice.balance, 0, "test_NativeReward::2");

        vm.prank(alice);
        hooks.claim(ids);

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
}

contract MockLBHooksBaseRewarder is LBHooksBaseRewarder {
    uint256 private _lastTimestamp;

    function give(address account, uint256 amount) public {
        _totalUnclaimedRewards += amount;
        _unclaimedRewards[account] += amount;
    }

    function _onHooksSet(bytes32 hooksParameters, bytes calldata data) internal override {
        super._onHooksSet(hooksParameters, data);

        _lastTimestamp = block.timestamp;
    }

    function _update() internal override returns (uint256) {
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

// contract MockLBPair {
//     bytes32 public getLBHooksParameters;

//     uint24 public getActiveId;
//     uint16 public getBinStep;

//     mapping(address => mapping(uint256 => uint256)) public balanceOf;
//     mapping(uint256 => uint256) public totalSupply;

//     function setHooksParameters(bytes32 parameters, bytes calldata data) public {
//         getLBHooksParameters = parameters;

//         Hooks.onHooksSet(parameters, data);
//     }

//     function setActiveId(uint24 activeId) public {
//         getActiveId = activeId;
//     }

//     function setBinStep(uint16 binStep) internal {
//         getBinStep = binStep;
//     }

//     function mint(address account, uint256[] memory ids, uint256[] memory amounts) public {
//         for (uint256 i = 0; i < ids.length; i++) {
//             uint256 id = ids[i];
//             uint256 amount = amounts[i];

//             balanceOf[account][id] += amount << 64;
//             totalSupply[id] += amount << 64;
//         }
//     }

//     function burn(address account, uint256 id, uint256 amount) public {
//         balanceOf[account][id] -= amount << 64;
//         totalSupply[id] -= amount << 64;
//     }

//     function getBin(uint24 id) public view returns (uint128 reserveX, uint128 reserveY) {
//         uint256 supply = totalSupply[id] >> 64;
//         uint24 activeId = getActiveId;

//         if (id > activeId) reserveX = uint128(supply);
//         if (id <= activeId) reserveY = uint128(supply);
//     }

//     function beforeSwap(address sender, address to, bool swapForY, bytes32 amountsIn) public {
//         Hooks.beforeSwap(getLBHooksParameters, sender, to, swapForY, amountsIn);
//     }

//     function afterSwap(address sender, address to, bool swapForY, bytes32 amountsOut) public {
//         Hooks.afterSwap(getLBHooksParameters, sender, to, swapForY, amountsOut);
//     }

//     function beforeMint(address sender, address to, bytes32[] calldata configs, bytes32 amounts) public {
//         Hooks.beforeMint(getLBHooksParameters, sender, to, configs, amounts);
//     }

//     function afterMint(address sender, address to, bytes32[] calldata configs, bytes32 amounts) public {
//         Hooks.afterMint(getLBHooksParameters, sender, to, configs, amounts);
//     }

//     function beforeBurn(
//         address sender,
//         address from,
//         address to,
//         uint256[] calldata ids,
//         uint256[] calldata amountsToBurn
//     ) public {
//         Hooks.beforeBurn(getLBHooksParameters, sender, from, to, ids, amountsToBurn);
//     }

//     function afterBurn(
//         address sender,
//         address from,
//         address to,
//         uint256[] calldata ids,
//         uint256[] calldata amountsToBurn
//     ) public {
//         Hooks.afterBurn(getLBHooksParameters, sender, from, to, ids, amountsToBurn);
//     }

//     function beforeFlashLoan(address sender, address to, bytes32 amounts) public {
//         Hooks.beforeFlashLoan(getLBHooksParameters, sender, to, amounts);
//     }

//     function afterFlashLoan(address sender, address to, bytes32 fees, bytes32 feesReceived) public {
//         Hooks.afterFlashLoan(getLBHooksParameters, sender, to, fees, feesReceived);
//     }

//     function beforeBatchTransferFrom(
//         address sender,
//         address from,
//         address to,
//         uint256[] calldata ids,
//         uint256[] calldata amounts
//     ) public {
//         Hooks.beforeBatchTransferFrom(getLBHooksParameters, sender, from, to, ids, amounts);
//     }

//     function afterBatchTransferFrom(
//         address sender,
//         address from,
//         address to,
//         uint256[] calldata ids,
//         uint256[] calldata amounts
//     ) public {
//         Hooks.afterBatchTransferFrom(getLBHooksParameters, sender, from, to, ids, amounts);
//     }
// }
