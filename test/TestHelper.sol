// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {LBFactory} from "@lb-protocol/src/LBFactory.sol";
import {LBPair, ILBPair, IERC20, LiquidityConfigurations} from "@lb-protocol/src/LBPair.sol";

import "./mocks/MockERC20.sol";

abstract contract TestHelper is Test {
    uint16 public constant DEFAULT_BIN_STEP = 25;
    uint24 public constant DEFAULT_ID = 2 ** 23;

    LBFactory public factory;

    ILBPair public pair01;
    ILBPair public pair02;
    ILBPair public pair12;

    IERC20 public token0;
    IERC20 public token1;
    IERC20 public token2;

    IERC20 public rewardToken01;
    IERC20 public rewardToken02;
    IERC20 public rewardToken12;

    address public feeRecipient = makeAddr("feeRecipient");

    function setUp() public virtual {
        factory = new LBFactory(feeRecipient, 1e16);

        token0 = IERC20(address(new MockERC20()));
        token1 = IERC20(address(new MockERC20()));
        token2 = IERC20(address(new MockERC20()));

        rewardToken01 = IERC20(address(new MockERC20()));
        rewardToken02 = IERC20(address(new MockERC20()));
        rewardToken12 = IERC20(address(new MockERC20()));

        address lbPairImplementation = address(new LBPair(factory));

        factory.setLBPairImplementation(lbPairImplementation);

        factory.addQuoteAsset(token1);
        factory.addQuoteAsset(token2);

        factory.setPreset(DEFAULT_BIN_STEP, 10_000, 50, 300, 5_000, 8_000, 1_000, 100_000, false);

        pair01 = factory.createLBPair(token0, token1, DEFAULT_ID, DEFAULT_BIN_STEP);
        pair02 = factory.createLBPair(token0, token2, DEFAULT_ID, DEFAULT_BIN_STEP);
        pair12 = factory.createLBPair(token1, token2, DEFAULT_ID, DEFAULT_BIN_STEP);

        vm.label(address(factory), "factory");

        vm.label(address(pair01), "pair01");
        vm.label(address(pair02), "pair02");
        vm.label(address(pair12), "pair12");

        vm.label(address(token0), "token0");
        vm.label(address(token1), "token1");
        vm.label(address(token2), "token2");

        vm.label(address(rewardToken01), "rewardToken01");
        vm.label(address(rewardToken02), "rewardToken02");
        vm.label(address(rewardToken12), "rewardToken12");
    }

    function _addLiquidity(
        ILBPair pair,
        address account,
        uint24 id,
        uint256 nbBins,
        uint256 amountXPerBin,
        uint256 amountYPerBin
    ) internal {
        uint24 activeId = pair.getActiveId();

        uint256 length = 2 * nbBins + 1;

        uint256 nbX;
        uint256 nbY;

        {
            uint256 amountX;
            uint256 amountY;

            for (uint256 i; i < length; i++) {
                uint24 binId = uint24(id - nbBins + i);

                if (binId > activeId) {
                    nbX += 2;
                    amountX += amountXPerBin;
                } else if (binId < activeId) {
                    nbY += 2;
                    amountY += amountYPerBin;
                } else {
                    nbX++;
                    nbY++;
                    amountX += amountXPerBin / 2;
                    amountY += amountYPerBin / 2;
                }
            }

            MockERC20 tokenX = MockERC20(address(pair.getTokenX()));
            MockERC20 tokenY = MockERC20(address(pair.getTokenY()));

            tokenX.mint(address(pair), amountX);
            tokenY.mint(address(pair), amountY);
        }

        bytes32[] memory liqConfigs = new bytes32[](length);
        for (uint256 i; i < length; i++) {
            uint24 binId = uint24(id - nbBins + i);

            uint64 weight = binId == activeId ? uint64(2e18) : uint64(1e18);

            liqConfigs[i] = LiquidityConfigurations.encodeParams(
                binId >= activeId ? weight / uint64(nbX) : 0, binId <= activeId ? weight / uint64(nbY) : 0, binId
            );
        }

        pair.mint(account, liqConfigs, account);
    }

    function _removeLiquidity(ILBPair pair, address account, uint24 id, uint256 nbBins, uint256 percent) internal {
        require(percent <= 1e18, "TestHelper: INVALID_PERCENT");

        uint256 length = 2 * nbBins + 1;

        uint256[] memory ids = new uint256[](length);
        uint256[] memory amounts = new uint256[](length);

        for (uint256 i; i < length; i++) {
            uint24 binId = uint24(id - nbBins + i);

            ids[i] = binId;
            amounts[i] = percent * pair.balanceOf(account, binId) / 1e18;
        }

        vm.prank(account);
        pair.burn(account, account, ids, amounts);
    }

    function _swap(ILBPair pair, address account, uint256 amountX, uint256 amountY) internal {
        require(amountX == 0 || amountY == 0, "TestHelper: INVALID_AMOUNTS");

        bool swapForY = amountX > 0;

        if (swapForY) MockERC20(address(pair.getTokenX())).mint(address(pair), amountX);
        else MockERC20(address(pair.getTokenY())).mint(address(pair), amountY);

        pair.swap(swapForY, account);
    }
}
