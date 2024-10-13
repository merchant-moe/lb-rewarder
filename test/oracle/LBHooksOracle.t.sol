// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "test/TestHelper.sol";

import "src/Oracle/LBHooksOracle.sol";
import "src/base/LBHooksBaseRewarder.sol";
import "./OracleId.t.sol";

contract MockLBHooksOracle is LBHooksBaseRewarder, LBHooksOracle {
    constructor(address manager) LBHooksBaseRewarder(manager) {}

    function getMaxNumberOfBins() public pure returns (uint256) {
        return MAX_NUMBER_OF_BINS;
    }

    function _onHooksSet(bytes calldata data) internal override {}

    function _onClaim(address user, uint256[] memory ids) internal override {}

    function _getPendingTotalRewards() internal view override returns (uint256 pendingTotalRewards) {}

    function _updateRewards() internal override returns (uint256 pendingTotalRewards) {}
}

contract TestLBHooksOracle is TestHelper {
    MockOracle oracle;
    OracleIdChainlink oracleId;
    MockLBHooksOracle lbHooks;

    function setUp() public override {
        super.setUp();

        oracle = new MockOracle();
        oracle.setDecimals(8);

        oracleId = new OracleIdChainlink(IChainlinkAggregatorV3(address(oracle)), false, 60, 1);

        lbHooksManager.setLBHooksParameters(
            ILBHooksManager.LBHooksType.SimpleRewarder,
            Hooks.setHooks(hooksParameters, address(new MockLBHooksOracle(address(lbHooksManager))))
        );

        lbHooks = MockLBHooksOracle(
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

    function test_Fuzz_SetParameters(int24 deltaBinA, int24 deltaBinB) public {
        oracle.setAnswer(1e8, block.timestamp);
        uint24 latestId = oracleId.getLatestId();

        deltaBinA = int24(bound(deltaBinA, type(int24).min, type(int24).max));
        int256 maxLastBin = int256(deltaBinA) + int256(lbHooks.getMaxNumberOfBins());
        deltaBinB = int24(bound(deltaBinB, deltaBinA, maxLastBin > type(int24).max ? type(int24).max : maxLastBin));
        (uint256 bStart, uint256 bEnd) = lbHooks.getRewardedRange();

        assertEq(bStart, 0, "test_Fuzz_SetParameters::1");
        assertEq(bEnd, 0, "test_Fuzz_SetParameters::2");

        lbHooks.setParameters(oracleId, deltaBinA, deltaBinB);
        (bStart, bEnd) = lbHooks.getRewardedRange();

        assertEq(bStart, uint256(int256(uint256(latestId)) + deltaBinA), "test_Fuzz_SetParameters::3");
        assertEq(bEnd, uint256(int256(uint256(latestId)) + deltaBinB), "test_Fuzz_SetParameters::4");

        lbHooks.setParameters(oracleId, 0, 0);
        (bStart, bEnd) = lbHooks.getRewardedRange();

        assertEq(bStart, latestId, "test_Fuzz_SetParameters::5");
        assertEq(bEnd, latestId, "test_Fuzz_SetParameters::6");

        lbHooks.setParameters(oracleId, deltaBinA, deltaBinB);
        (bStart, bEnd) = lbHooks.getRewardedRange();

        assertEq(bStart, uint256(int256(uint256(latestId)) + deltaBinA), "test_Fuzz_SetParameters::7");
        assertEq(bEnd, uint256(int256(uint256(latestId)) + deltaBinB), "test_Fuzz_SetParameters::8");

        lbHooks.setParameters(IOracleId(address(0)), deltaBinA, deltaBinB);
        (bStart, bEnd) = lbHooks.getRewardedRange();

        assertEq(bStart, 0, "test_Fuzz_SetParameters::9");
        assertEq(bEnd, 0, "test_Fuzz_SetParameters::10");
    }

    function test_Fuzz_Revert_SetRange(int24 binStart, int24 binEnd) public {
        oracle.setAnswer(1e8, block.timestamp);
        uint24 latestId = oracleId.getLatestId();

        int24 bStart = int24(bound(binStart, type(int24).min + 1, type(int24).max));
        int24 bEnd = int24(bound(binEnd, type(int24).min, bStart - 1));

        vm.expectRevert(LBHooksOracle.LBHooksOracle__InvalidDeltaBins.selector);
        lbHooks.setParameters(oracleId, bStart, bEnd);

        uint24 maxNumberOfBins = uint24(lbHooks.getMaxNumberOfBins());

        bStart = int24(bound(binStart, type(int24).min, type(int24).max - int24(maxNumberOfBins + 1)));
        bEnd = int24(bound(binEnd, bStart + int24(maxNumberOfBins) + 1, type(int24).max));

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__ExceedsMaxNumberOfBins.selector);
        lbHooks.setParameters(oracleId, int24(bStart), int24(bEnd));

        oracle.setAnswer(1e18, block.timestamp);
        latestId = oracleId.getLatestId();

        bStart = int24(bound(binStart, int24(type(uint24).max - latestId) + 1, type(int24).max));

        vm.expectRevert(ILBHooksBaseRewarder.LBHooksBaseRewarder__Overflow.selector);
        lbHooks.setParameters(oracleId, bStart, bStart);
    }
}
