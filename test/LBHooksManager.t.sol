// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./TestHelper.sol";

import "../src/LBHooksRewarder.sol";
import "../src/LBHooksExtraRewarder.sol";

contract LBHooksManagerTest is TestHelper {
    bytes32 rewarderHooksParameters;
    bytes32 extraRewarderHooksParameters;

    function setUp() public override {
        super.setUp();

        rewarderHooksParameters =
            Hooks.setHooks(hooksParameters, address(new LBHooksRewarder(address(lbHooksManager), masterchef, moe)));
        extraRewarderHooksParameters =
            Hooks.setHooks(hooksParameters, address(new LBHooksExtraRewarder(address(lbHooksManager))));
    }

    function test_GetLBHooksParameters() public {
        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.Rewarder, rewarderHooksParameters);
        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.ExtraRewarder, extraRewarderHooksParameters);

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.Rewarder),
            rewarderHooksParameters,
            "test_GetLBHooksParameters::1"
        );

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.ExtraRewarder),
            extraRewarderHooksParameters,
            "test_GetLBHooksParameters::2"
        );

        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.Rewarder, bytes32(0));

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.Rewarder),
            bytes32(0),
            "test_GetLBHooksParameters::3"
        );

        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.ExtraRewarder, bytes32(0));

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.ExtraRewarder),
            bytes32(0),
            "test_GetLBHooksParameters::4"
        );

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.ExtraRewarder),
            bytes32(0),
            "test_GetLBHooksParameters::5"
        );

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.Invalid),
            bytes32(0),
            "test_GetLBHooksParameters::6"
        );

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.Invalid),
            bytes32(0),
            "test_GetLBHooksParameters::7"
        );

        vm.expectRevert(ILBHooksManager.LBHooksManager__InvalidLBHooksType.selector);
        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.Invalid, bytes32(0));
    }

    function test_CreateLBHooksRewarder() public {
        vm.expectRevert(ILBHooksManager.LBHooksManager__LBPairNotFound.selector);
        lbHooksManager.createLBHooksRewarder(
            IERC20(address(token0)), IERC20(address(token0)), DEFAULT_BIN_STEP, address(this)
        );

        vm.expectRevert(ILBHooksManager.LBHooksManager__LBHooksParametersNotSet.selector);
        lbHooksManager.createLBHooksRewarder(
            IERC20(address(token0)), IERC20(address(token1)), DEFAULT_BIN_STEP, address(this)
        );

        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.Rewarder, rewarderHooksParameters);

        assertEq(
            lbHooksManager.getHooksLength(ILBHooksManager.LBHooksType.Rewarder), 0, "test_CreateLBHooksRewarder::1"
        );

        LBHooksRewarder lbHooks = LBHooksRewarder(
            payable(
                address(
                    lbHooksManager.createLBHooksRewarder(
                        IERC20(address(token0)), IERC20(address(token1)), DEFAULT_BIN_STEP, address(this)
                    )
                )
            )
        );

        assertEq(
            lbHooksManager.getHooksLength(ILBHooksManager.LBHooksType.Rewarder), 1, "test_CreateLBHooksRewarder::2"
        );
        assertEq(
            address(lbHooksManager.getHooksAt(ILBHooksManager.LBHooksType.Rewarder, 0)),
            address(lbHooks),
            "test_CreateLBHooksRewarder::3"
        );
        assertEq(
            uint8(lbHooksManager.getLBHooksType(lbHooks)),
            uint8(ILBHooksManager.LBHooksType.Rewarder),
            "test_CreateLBHooksRewarder::4"
        );
    }

    function test_CreateLBHooksExtraRewarder() public {
        vm.expectRevert(ILBHooksManager.LBHooksManager__LBPairNotFound.selector);
        lbHooksManager.createLBHooksExtraRewarder(
            IERC20(address(token0)), IERC20(address(token0)), DEFAULT_BIN_STEP, IERC20(address(0)), address(this)
        );

        vm.expectRevert(ILBHooksManager.LBHooksManager__LBHooksParametersNotSet.selector);
        lbHooksManager.createLBHooksExtraRewarder(
            IERC20(address(token0)), IERC20(address(token1)), DEFAULT_BIN_STEP, IERC20(address(0)), address(this)
        );

        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.Rewarder, rewarderHooksParameters);
        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.ExtraRewarder, extraRewarderHooksParameters);

        vm.expectRevert(ILBHooksManager.LBHooksManager__LBHooksNotSetOnPair.selector);
        lbHooksManager.createLBHooksExtraRewarder(
            IERC20(address(token0)), IERC20(address(token1)), DEFAULT_BIN_STEP, IERC20(address(0)), address(this)
        );

        lbHooksManager.createLBHooksRewarder(
            IERC20(address(token0)), IERC20(address(token1)), DEFAULT_BIN_STEP, address(this)
        );

        assertEq(
            lbHooksManager.getHooksLength(ILBHooksManager.LBHooksType.ExtraRewarder),
            0,
            "test_CreateLBHooksExtraRewarder::1"
        );

        ILBHooksExtraRewarder lbHooks = lbHooksManager.createLBHooksExtraRewarder(
            IERC20(address(token0)), IERC20(address(token1)), DEFAULT_BIN_STEP, IERC20(address(0)), address(this)
        );

        assertEq(
            lbHooksManager.getHooksLength(ILBHooksManager.LBHooksType.ExtraRewarder),
            1,
            "test_CreateLBHooksExtraRewarder::2"
        );
        assertEq(
            address(lbHooksManager.getHooksAt(ILBHooksManager.LBHooksType.ExtraRewarder, 0)),
            address(lbHooks),
            "test_CreateLBHooksExtraRewarder::3"
        );
        assertEq(
            uint8(lbHooksManager.getLBHooksType(lbHooks)),
            uint8(ILBHooksManager.LBHooksType.ExtraRewarder),
            "test_CreateLBHooksExtraRewarder::4"
        );
    }
}
