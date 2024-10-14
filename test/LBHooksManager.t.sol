// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "test/TestHelper.sol";

import "src/delta/LBHooksDeltaMCRewarder.sol";
import "src/delta/LBHooksDeltaExtraRewarder.sol";

contract LBHooksManagerTest is TestHelper {
    bytes32 rewarderHooksParameters;
    bytes32 extraRewarderHooksParameters;

    function setUp() public override {
        super.setUp();

        rewarderHooksParameters = Hooks.setHooks(
            hooksParameters, address(new LBHooksDeltaMCRewarder(address(lbHooksManager), masterchef, moe))
        );
        extraRewarderHooksParameters =
            Hooks.setHooks(hooksParameters, address(new LBHooksDeltaExtraRewarder(address(lbHooksManager))));
    }

    function test_GetLBHooksParameters() public {
        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.DeltaMCRewarder, rewarderHooksParameters);
        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.DeltaExtraRewarder, extraRewarderHooksParameters
        );

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.DeltaMCRewarder),
            rewarderHooksParameters,
            "test_GetLBHooksParameters::1"
        );

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.DeltaExtraRewarder),
            extraRewarderHooksParameters,
            "test_GetLBHooksParameters::2"
        );

        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.DeltaMCRewarder, bytes32(0));

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.DeltaMCRewarder),
            bytes32(0),
            "test_GetLBHooksParameters::3"
        );

        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.DeltaExtraRewarder, bytes32(0));

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.DeltaExtraRewarder),
            bytes32(0),
            "test_GetLBHooksParameters::4"
        );

        assertEq(
            lbHooksManager.getLBHooksParameters(ILBHooksManager.LBHooksType.DeltaExtraRewarder),
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

    function test_createLBHooksMCRewarder() public {
        vm.expectRevert(ILBHooksManager.LBHooksManager__LBPairNotFound.selector);
        lbHooksManager.createLBHooksMCRewarder(
            ILBHooksManager.LBHooksType.DeltaMCRewarder,
            IERC20(address(token0)),
            IERC20(address(token0)),
            DEFAULT_BIN_STEP,
            address(this)
        );

        vm.expectRevert(ILBHooksManager.LBHooksManager__UnorderedTokens.selector);
        lbHooksManager.createLBHooksMCRewarder(
            ILBHooksManager.LBHooksType.DeltaMCRewarder,
            IERC20(address(token1)),
            IERC20(address(token0)),
            DEFAULT_BIN_STEP,
            address(this)
        );

        vm.expectRevert(ILBHooksManager.LBHooksManager__LBHooksParametersNotSet.selector);
        lbHooksManager.createLBHooksMCRewarder(
            ILBHooksManager.LBHooksType.DeltaMCRewarder,
            IERC20(address(token0)),
            IERC20(address(token1)),
            DEFAULT_BIN_STEP,
            address(this)
        );

        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.DeltaMCRewarder, rewarderHooksParameters);

        assertEq(
            lbHooksManager.getHooksLength(ILBHooksManager.LBHooksType.DeltaMCRewarder),
            0,
            "test_createLBHooksMCRewarder::1"
        );

        LBHooksDeltaMCRewarder lbHooks = LBHooksDeltaMCRewarder(
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

        assertEq(
            lbHooksManager.getHooksLength(ILBHooksManager.LBHooksType.DeltaMCRewarder),
            1,
            "test_createLBHooksMCRewarder::2"
        );
        assertEq(
            address(lbHooksManager.getHooksAt(ILBHooksManager.LBHooksType.DeltaMCRewarder, 0)),
            address(lbHooks),
            "test_createLBHooksMCRewarder::3"
        );
        assertEq(
            uint8(lbHooksManager.getLBHooksType(lbHooks)),
            uint8(ILBHooksManager.LBHooksType.DeltaMCRewarder),
            "test_createLBHooksMCRewarder::4"
        );
    }

    function test_CreateLBHooksExtraRewarder() public {
        vm.expectRevert(ILBHooksManager.LBHooksManager__LBPairNotFound.selector);
        lbHooksManager.createLBHooksExtraRewarder(
            ILBHooksManager.LBHooksType.DeltaExtraRewarder,
            IERC20(address(token0)),
            IERC20(address(token0)),
            DEFAULT_BIN_STEP,
            IERC20(address(0)),
            address(this)
        );

        vm.expectRevert(ILBHooksManager.LBHooksManager__UnorderedTokens.selector);
        lbHooksManager.createLBHooksExtraRewarder(
            ILBHooksManager.LBHooksType.DeltaExtraRewarder,
            IERC20(address(token1)),
            IERC20(address(token0)),
            DEFAULT_BIN_STEP,
            IERC20(address(0)),
            address(this)
        );

        vm.expectRevert(ILBHooksManager.LBHooksManager__LBHooksParametersNotSet.selector);
        lbHooksManager.createLBHooksExtraRewarder(
            ILBHooksManager.LBHooksType.DeltaExtraRewarder,
            IERC20(address(token0)),
            IERC20(address(token1)),
            DEFAULT_BIN_STEP,
            IERC20(address(0)),
            address(this)
        );

        lbHooksManager.setLBHooksParameters(ILBHooksManager.LBHooksType.DeltaMCRewarder, rewarderHooksParameters);
        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.DeltaExtraRewarder, extraRewarderHooksParameters
        );

        vm.expectRevert(ILBHooksManager.LBHooksManager__LBHooksNotSetOnPair.selector);
        lbHooksManager.createLBHooksExtraRewarder(
            ILBHooksManager.LBHooksType.DeltaExtraRewarder,
            IERC20(address(token0)),
            IERC20(address(token1)),
            DEFAULT_BIN_STEP,
            IERC20(address(0)),
            address(this)
        );

        lbHooksManager.createLBHooksMCRewarder(
            ILBHooksManager.LBHooksType.DeltaMCRewarder,
            IERC20(address(token0)),
            IERC20(address(token1)),
            DEFAULT_BIN_STEP,
            address(this)
        );

        assertEq(
            lbHooksManager.getHooksLength(ILBHooksManager.LBHooksType.DeltaExtraRewarder),
            0,
            "test_CreateLBHooksExtraRewarder::1"
        );

        ILBHooksExtraRewarder lbHooks = ILBHooksExtraRewarder(
            lbHooksManager.createLBHooksExtraRewarder(
                ILBHooksManager.LBHooksType.DeltaExtraRewarder,
                IERC20(address(token0)),
                IERC20(address(token1)),
                DEFAULT_BIN_STEP,
                IERC20(address(0)),
                address(this)
            )
        );

        assertEq(
            lbHooksManager.getHooksLength(ILBHooksManager.LBHooksType.DeltaExtraRewarder),
            1,
            "test_CreateLBHooksExtraRewarder::2"
        );
        assertEq(
            address(lbHooksManager.getHooksAt(ILBHooksManager.LBHooksType.DeltaExtraRewarder, 0)),
            address(lbHooks),
            "test_CreateLBHooksExtraRewarder::3"
        );
        assertEq(
            uint8(lbHooksManager.getLBHooksType(lbHooks)),
            uint8(ILBHooksManager.LBHooksType.DeltaExtraRewarder),
            "test_CreateLBHooksExtraRewarder::4"
        );
    }
}
