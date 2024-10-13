// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "test/TestHelper.sol";

import "src/static/LBHooksStatic.sol";
import "src/base/LBHooksBaseRewarder.sol";

contract MockLBHooksStatic is LBHooksBaseRewarder, LBHooksStatic {
    constructor(address manager) LBHooksBaseRewarder(manager) {}

    function getMaxNumberOfBins() public pure returns (uint256) {
        return MAX_NUMBER_OF_BINS;
    }

    function _onHooksSet(bytes calldata data) internal override {}

    function _onClaim(address user, uint256[] memory ids) internal override {}

    function _getPendingTotalRewards() internal view override returns (uint256 pendingTotalRewards) {}

    function _updateRewards() internal override returns (uint256 pendingTotalRewards) {}
}

contract TestLBHooksStatic is TestHelper {
    MockLBHooksStatic lbHooks;

    function setUp() public override {
        super.setUp();

        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.SimpleRewarder,
            Hooks.setHooks(hooksParameters, address(new MockLBHooksStatic(address(lbHooksManager))))
        );

        lbHooks = MockLBHooksStatic(
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
    }

    function test_Fuzz_SetRange(uint24 binStart, uint24 binEnd) public {
        uint256 maxLastBin = binStart + lbHooks.getMaxNumberOfBins();
        binEnd = uint24(bound(binEnd, binStart, maxLastBin > type(uint24).max ? type(uint24).max : maxLastBin));
        (uint256 bStart, uint256 bEnd) = lbHooks.getRewardedRange();

        assertEq(bStart, 0, "test_Fuzz_SetRange::1");
        assertEq(bEnd, 0, "test_Fuzz_SetRange::2");

        lbHooks.setRange(binStart, binEnd);
        (bStart, bEnd) = lbHooks.getRewardedRange();

        assertEq(bStart, binStart, "test_Fuzz_SetRange::3");
        assertEq(bEnd, binEnd, "test_Fuzz_SetRange::4");

        lbHooks.setRange(0, 0);
        (bStart, bEnd) = lbHooks.getRewardedRange();

        assertEq(bStart, 0, "test_Fuzz_SetRange::5");
        assertEq(bEnd, 0, "test_Fuzz_SetRange::6");

        lbHooks.setRange(binStart, binEnd);
        (bStart, bEnd) = lbHooks.getRewardedRange();

        assertEq(bStart, binStart, "test_Fuzz_SetRange::7");
        assertEq(bEnd, binEnd, "test_Fuzz_SetRange::8");
    }

    function test_Fuzz_Revert_SetRange(uint24 binStart, uint24 binEnd) public {
        uint24 bStart = uint24(bound(binStart, 1, type(uint24).max));
        uint24 bEnd = uint24(bound(binEnd, 0, bStart - 1));

        vm.expectRevert(LBHooksStatic.LBHooksStatic__InvalidBins.selector);
        lbHooks.setRange(bStart, bEnd);

        uint256 maxNumberOfBins = lbHooks.getMaxNumberOfBins();

        bStart = uint24(bound(binStart, 0, type(uint24).max - (maxNumberOfBins + 1)));
        bEnd = uint24(bound(binEnd, bStart + maxNumberOfBins + 1, type(uint24).max));

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__ExceedsMaxNumberOfBins.selector);
        lbHooks.setRange(bStart, bEnd);
    }
}
