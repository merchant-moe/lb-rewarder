// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "src/Oracle/OracleIdChainlink.sol";

contract MockOracle {
    uint8 public decimals;
    int256 public answer;
    uint256 updatedAt;

    function setDecimals(uint8 _decimals) public {
        decimals = _decimals;
    }

    function setAnswer(int256 _answer, uint256 _updatedAt) public {
        answer = _answer;
        updatedAt = _updatedAt;
    }

    function latestRoundData() public view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, answer, 0, updatedAt, 0);
    }
}

contract TestOracleId is Test {
    MockOracle oracle;
    OracleIdChainlink oracleId;
    OracleIdChainlink oracleIdInversed;

    function setUp() public {
        oracle = new MockOracle();
        oracle.setDecimals(8);

        oracleId = new OracleIdChainlink(IChainlinkAggregatorV3(address(oracle)), false, 60, 1);
        oracleIdInversed = new OracleIdChainlink(IChainlinkAggregatorV3(address(oracle)), true, 60, 1);
    }

    function test_Constructor() public {
        (IChainlinkAggregatorV3 o, bool isInverse, uint256 oraclePrecision, uint256 heartbeat, uint256 binStep) =
            oracleId.getOracleIdParameters();

        assertEq(address(o), address(oracle), "test_Constructor::1");
        assertEq(isInverse, false, "test_Constructor::2");
        assertEq(oraclePrecision, 10 ** 8, "test_Constructor::3");
        assertEq(heartbeat, 60, "test_Constructor::4");
        assertEq(binStep, 1, "test_Constructor::5");

        (o, isInverse, oraclePrecision, heartbeat, binStep) = oracleIdInversed.getOracleIdParameters();

        assertEq(address(o), address(oracle), "test_Constructor::6");
        assertEq(isInverse, true, "test_Constructor::7");
        assertEq(oraclePrecision, 10 ** 8, "test_Constructor::8");
        assertEq(heartbeat, 60, "test_Constructor::9");
        assertEq(binStep, 1, "test_Constructor::10");
    }

    function test_Fuzz_GetOracleId(int256 price) public {
        price = bound(price, 1, int256(uint256(type(uint128).max)));

        oracle.setAnswer(price, block.timestamp);

        uint24 id = oracleId.getLatestId();

        uint256 priceX128 = (uint256(price) << 128) / 1e8;

        uint256 priceAtIdMinus1 = PriceHelper.getPriceFromId(id - 1, 1);
        uint256 priceAtId = PriceHelper.getPriceFromId(id, 1);
        uint256 priceAtIdPlus1 = PriceHelper.getPriceFromId(id + 1, 1);

        assertLt(priceAtIdMinus1, priceX128, "test_Fuzz_GetOracleId::1");
        assertLe(priceAtId, priceX128, "test_Fuzz_GetOracleId::2");
        assertGt(priceAtIdPlus1, priceX128, "test_Fuzz_GetOracleId::3");
    }

    function test_Fuzz_GetOracleIdInversed(int256 price) public {
        price = bound(price, 1, int256(uint256(type(uint128).max)));

        oracle.setAnswer(price, block.timestamp);

        uint24 id = oracleIdInversed.getLatestId();

        uint256 priceX128 = (uint256(1e8) << 128) / uint256(price);

        uint256 priceAtIdMinus1 = PriceHelper.getPriceFromId(id - 1, 1);
        uint256 priceAtId = PriceHelper.getPriceFromId(id, 1);
        uint256 priceAtIdPlus1 = PriceHelper.getPriceFromId(id + 1, 1);

        assertLt(priceAtIdMinus1, priceX128, "test_Fuzz_GetOracleIdInversed::1");
        assertLe(priceAtId, priceX128, "test_Fuzz_GetOracleIdInversed::2");
        assertGt(priceAtIdPlus1, priceX128, "test_Fuzz_GetOracleIdInversed::3");
    }

    function test_Fuzz_Revert_GetOracleId(int256 price) public {
        int256 p = bound(price, type(int256).min, 0);

        oracle.setAnswer(p, block.timestamp);

        vm.expectRevert(OracleIdChainlink.OracleIdChainlink__InvalidPrice.selector);
        oracleId.getLatestId();

        p = bound(price, int256(uint256(type(uint128).max)) + 1, type(int256).max);

        oracle.setAnswer(p, block.timestamp);

        vm.expectRevert(OracleIdChainlink.OracleIdChainlink__InvalidPrice.selector);
        oracleId.getLatestId();

        vm.warp(type(uint256).max);

        uint256 latestUpdatedAt = bound(uint256(price), 0, block.timestamp - (60 + 1));

        oracle.setAnswer(1e8, latestUpdatedAt);

        vm.expectRevert(OracleIdChainlink.OracleIdChainlink__StalePrice.selector);
        oracleId.getLatestId();
    }
}
