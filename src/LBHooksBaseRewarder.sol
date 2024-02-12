// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {LBBaseHooks, ILBHooks} from "@lb-protocol/src/LBBaseHooks.sol";
import {Uint256x256Math} from "@lb-protocol/src/libraries/math/Uint256x256Math.sol";
import {ILBPair} from "@lb-protocol/src/interfaces/ILBPair.sol";
import {PriceHelper} from "@lb-protocol/src/libraries/PriceHelper.sol";
import {BinHelper} from "@lb-protocol/src/libraries/BinHelper.sol";
import {Hooks} from "@lb-protocol/src/libraries/Hooks.sol";
import {ILBHooksBaseRewarder} from "./interfaces/ILBHooksBaseRewarder.sol";
import {ILBHooksExtraRewarder} from "./interfaces/ILBHooksExtraRewarder.sol";

abstract contract LBHooksBaseRewarder is LBBaseHooks, Ownable2StepUpgradeable, ILBHooksBaseRewarder {
    using Uint256x256Math for uint256;
    using SafeERC20 for IERC20;

    address public immutable implementation;

    uint8 internal constant OFFSET_PRECISION = 128;
    bytes32 internal constant FLAGS = Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_MINT_FLAG | Hooks.AFTER_MINT_FLAG
        | Hooks.BEFORE_BURN_FLAG | Hooks.AFTER_BURN_FLAG | Hooks.BEFORE_TRANSFER_FLAG | Hooks.AFTER_TRANSFER_FLAG;

    address internal _extraHooksRewarder;

    int24 internal _deltaBinA;
    int24 internal _deltaBinB;

    uint256 internal _totalUnclaimedRewards;

    mapping(uint256 => Bin) internal _bins;
    mapping(address => uint256) internal _unclaimedRewards;

    constructor() {
        implementation = address(this);

        _disableInitializers();
    }

    receive() external payable {
        _nativeReceived();
    }

    fallback() external payable {
        _nativeReceived();
    }

    function getRewardToken() external view virtual returns (IERC20) {
        return _getRewardToken();
    }

    function isStopped() external view virtual returns (bool) {
        return _isLinked();
    }

    // not safe if ids has duplicates
    function getPendingRewards(address user, uint256[] calldata ids)
        external
        view
        virtual
        returns (uint256 pendingRewards)
    {
        if (!_isLinked()) return 0;

        ILBPair lbPair = _getLBPair();

        (uint256[] memory rewardedIds, uint256 binStart, uint256 binEnd) = _getRewardedRange();
        (uint256[] memory liquiditiesX128, uint256[] memory totalSuppliesX64, uint256 totalLiquiditiesX128) =
            _getLiquidityData(lbPair, rewardedIds);

        address user_ = user; // Avoid stack too deep error

        uint256 pendingTotalRewards = _getPendingTotalRewards();

        for (uint256 i; i < ids.length; ++i) {
            uint24 id = uint24(ids[i]);

            uint256 accRewardsPerShareX64;
            uint256 userAccRewardsPerShareX64;

            {
                Bin storage bin = _bins[id];

                accRewardsPerShareX64 = bin.accRewardsPerShareX64;
                userAccRewardsPerShareX64 = bin.userAccRewardsPerShareX64[user_];
            }

            if (id >= binStart && id < binEnd) {
                uint256 index = id - binStart;
                uint256 totalSupplyX64 = totalSuppliesX64[index];
                if (totalSupplyX64 > 0 && totalLiquiditiesX128 > 0) {
                    uint256 weightX128 =
                        liquiditiesX128[index].shiftDivRoundDown(OFFSET_PRECISION, totalLiquiditiesX128);

                    accRewardsPerShareX64 += pendingTotalRewards.mulDivRoundDown(weightX128, totalSupplyX64);
                }
            }

            uint256 balanceX64 = lbPair.balanceOf(user_, id);

            if (accRewardsPerShareX64 > userAccRewardsPerShareX64) {
                unchecked {
                    pendingRewards += (accRewardsPerShareX64 - userAccRewardsPerShareX64).mulShiftRoundDown(
                        balanceX64, OFFSET_PRECISION
                    );
                }
            }
        }

        return pendingRewards + _unclaimedRewards[user];
    }

    function claim(uint256[] calldata ids) external virtual {
        if (!_isLinked()) revert LBHooksBaseRewarder__UnlinkedHooks();

        _updateAccruedRewardsPerShare();
        _updateUser(msg.sender, ids);
        _claim(msg.sender, _unclaimedRewards[msg.sender]);
    }

    function setDeltaBins(int24 deltaBinA, int24 deltaBinB) external virtual onlyOwner {
        if (deltaBinA > deltaBinB) revert LBHooksBaseRewarder__InvalidDeltaBins();

        _updateAccruedRewardsPerShare();

        _deltaBinA = deltaBinA;
        _deltaBinB = deltaBinB;

        emit DeltaBinsSet(deltaBinA, deltaBinB);
    }

    function setExtraHooksRewarder(address extraHooksRewarder, bytes calldata extraRewarderData)
        external
        virtual
        onlyOwner
    {
        _extraHooksRewarder = extraHooksRewarder;

        if (extraHooksRewarder != address(0)) {
            if (
                ILBHooksExtraRewarder(extraHooksRewarder).getLBPair() != _getLBPair()
                    || ILBHooksExtraRewarder(extraHooksRewarder).getParentRewarder() != address(this)
            ) {
                revert LBHooksBaseRewarder__InvalidExtraHooksRewarder();
            }

            Hooks.onHooksSet(_getExtraHooksParameters(), extraRewarderData);
        }

        emit ExtraHooksRewarderSet(extraHooksRewarder);
    }

    function sweep(IERC20 token, address to) external virtual onlyOwner {
        uint256 balance = _balanceOfThis(token);

        if (_isLinked() && token == _getRewardToken()) revert LBHooksBaseRewarder__LockedRewardToken();
        if (balance == 0) revert LBHooksBaseRewarder__ZeroBalance();

        _safeTransfer(token, to, balance);
    }

    function _balanceOfThis(IERC20 token) internal view virtual returns (uint256) {
        return address(token) == address(0) ? address(this).balance : token.balanceOf(address(this));
    }

    function _getRewardToken() internal view virtual returns (IERC20) {
        return IERC20(_getArgAddress(20));
    }

    function _getRewardedRange()
        internal
        view
        virtual
        returns (uint256[] memory rewardedIds, uint256 binStart, uint256 binEnd)
    {
        uint24 activeId = _getLBPair().getActiveId();
        (int24 deltaBinA, int24 deltaBinB) = (_deltaBinA, _deltaBinB);

        binStart = uint256(int256(uint256(activeId)) + deltaBinA);
        binEnd = uint256(int256(uint256(activeId)) + deltaBinB);

        if (binStart > type(uint24).max || binEnd > type(uint24).max) revert LBHooksBaseRewarder__Overflow();

        uint256 length = binEnd - binStart;
        rewardedIds = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            unchecked {
                rewardedIds[i] = uint24(binStart + i);
            }
        }
    }

    function _getLiquidityData(ILBPair lbPair, uint256[] memory ids)
        internal
        view
        virtual
        returns (uint256[] memory liquiditiesX128, uint256[] memory totalSuppliesX64, uint256 totalLiquiditiesX128)
    {
        uint16 binStep = lbPair.getBinStep();

        uint256 length = ids.length;

        liquiditiesX128 = new uint256[](length);
        totalSuppliesX64 = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            uint24 id = uint24(ids[i]);

            (uint128 binReserveX, uint128 binReserveY) = lbPair.getBin(id);
            uint256 priceX128 = PriceHelper.getPriceFromId(id, binStep);

            uint256 totalSupplyX64 = lbPair.totalSupply(id);
            uint256 liquidityX128 = BinHelper.getLiquidity(binReserveX, binReserveY, priceX128);

            liquiditiesX128[i] = liquidityX128;
            totalSuppliesX64[i] = totalSupplyX64;

            totalLiquiditiesX128 += liquidityX128;
        }
    }

    function _convertLiquidityConfigs(bytes32[] memory liquidityConfigs)
        internal
        pure
        virtual
        returns (uint256[] memory ids)
    {
        assembly {
            ids := liquidityConfigs
        }
    }

    function _getExtraHooksParameters() internal view virtual returns (bytes32 hooksParameters) {
        address extraHooksRewarder = _extraHooksRewarder;

        if (extraHooksRewarder == address(0)) return 0;

        bytes32 flags = FLAGS;

        return Hooks.setHooks(flags, extraHooksRewarder);
    }

    function _nativeReceived() internal view virtual {
        if (address(_getRewardToken()) != address(0)) revert LBHooksBaseRewarder__NotNativeRewarder();
        if (msg.value == 0) revert LBHooksBaseRewarder__NoValueReceived();
        if (msg.data.length != _getImmutableArgsOffset()) revert LBHooksBaseRewarder__NotImplemented();
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal virtual {
        if (amount > 0) {
            if (address(token) == address(0)) {
                (bool s,) = to.call{value: amount}("");
                if (!s) revert LBHooksBaseRewarder__NativeTransferFailed();
            } else {
                token.safeTransfer(to, amount);
            }
        }
    }

    function _updateAccruedRewardsPerShare() internal virtual {
        uint256 pendingTotalRewards = _update();

        if (pendingTotalRewards == 0) return;

        ILBPair lbPair = _getLBPair();

        (uint256[] memory ids,,) = _getRewardedRange();
        (uint256[] memory liquiditiesX128, uint256[] memory totalSuppliesX64, uint256 totalLiquiditiesX128) =
            _getLiquidityData(lbPair, ids);

        if (totalLiquiditiesX128 == 0) return;

        _totalUnclaimedRewards += pendingTotalRewards;

        uint256 length = ids.length;
        for (uint256 i; i < length; ++i) {
            uint256 totalSupplyX64 = totalSuppliesX64[i];
            if (totalSupplyX64 > 0) {
                uint256 weightX128 = liquiditiesX128[i].shiftDivRoundDown(OFFSET_PRECISION, totalLiquiditiesX128);
                _bins[ids[i]].accRewardsPerShareX64 += pendingTotalRewards.mulDivRoundDown(weightX128, totalSupplyX64);
            }
        }
    }

    function _updateUser(address to, uint256[] memory ids) internal virtual returns (uint256 pendingRewards) {
        ILBPair lbPair = _getLBPair();

        uint256 length = ids.length;
        for (uint256 i; i < length; ++i) {
            uint24 id = uint24(ids[i]);
            uint256 balanceX64 = lbPair.balanceOf(to, id);

            Bin storage bin = _bins[id];

            uint256 accRewardsPerShareX64 = bin.accRewardsPerShareX64;
            uint256 userAccRewardsPerShareX64 = bin.userAccRewardsPerShareX64[to];

            if (accRewardsPerShareX64 > userAccRewardsPerShareX64) {
                unchecked {
                    pendingRewards += (accRewardsPerShareX64 - userAccRewardsPerShareX64).mulShiftRoundDown(
                        balanceX64, OFFSET_PRECISION
                    );
                }

                bin.userAccRewardsPerShareX64[to] = accRewardsPerShareX64;
            }
        }

        if (pendingRewards > 0) {
            _unclaimedRewards[to] += pendingRewards;
        }
    }

    function _claim(address user, uint256 rewards) internal virtual {
        if (rewards == 0) return;

        _totalUnclaimedRewards -= rewards;
        _unclaimedRewards[user] -= rewards;

        _safeTransfer(_getRewardToken(), user, rewards);
    }

    function _onHooksSet(bytes32 hooksParameters, bytes calldata data) internal virtual override initializer {
        if (hooksParameters != Hooks.setHooks(FLAGS, address(this))) {
            revert LBHooksBaseRewarder__InvalidHooksParameters();
        }

        address owner = abi.decode(data, (address));
        __Ownable_init(owner);

        bytes32 extraHooksParameters = _getExtraHooksParameters();
        if (extraHooksParameters != 0) {
            Hooks.onHooksSet(extraHooksParameters, data);
        }
    }

    function _beforeSwap(address sender, address to, bool swapForY, bytes32 amountsIn) internal virtual override {
        _updateAccruedRewardsPerShare();

        Hooks.beforeSwap(_getExtraHooksParameters(), sender, to, swapForY, amountsIn);
    }

    function _beforeMint(address from, address to, bytes32[] calldata liquidityConfigs, bytes32 amountsReceived)
        internal
        virtual
        override
    {
        _updateAccruedRewardsPerShare();
        _updateUser(to, _convertLiquidityConfigs(liquidityConfigs));

        Hooks.beforeMint(_getExtraHooksParameters(), from, to, liquidityConfigs, amountsReceived);
    }

    function _afterMint(address from, address to, bytes32[] calldata liquidityConfigs, bytes32 amountsIn)
        internal
        virtual
        override
    {
        _claim(to, _unclaimedRewards[to]);

        Hooks.afterMint(_getExtraHooksParameters(), from, to, liquidityConfigs, amountsIn);
    }

    function _beforeBurn(
        address sender,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amountsToBurn
    ) internal virtual override {
        _updateAccruedRewardsPerShare();
        _updateUser(from, ids);

        Hooks.beforeBurn(_getExtraHooksParameters(), sender, from, to, ids, amountsToBurn);
    }

    function _afterBurn(
        address sender,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amountsToBurn
    ) internal virtual override {
        _claim(from, _unclaimedRewards[from]);

        Hooks.afterBurn(_getExtraHooksParameters(), sender, from, to, ids, amountsToBurn);
    }

    function _beforeBatchTransferFrom(
        address sender,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) internal virtual override {
        _updateAccruedRewardsPerShare();

        _updateUser(from, ids);
        _updateUser(to, ids);

        Hooks.beforeBatchTransferFrom(_getExtraHooksParameters(), sender, from, to, ids, amounts);
    }

    function _afterBatchTransferFrom(
        address sender,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) internal virtual override {
        _claim(from, _unclaimedRewards[from]);

        Hooks.afterBatchTransferFrom(_getExtraHooksParameters(), sender, from, to, ids, amounts);
    }

    function _getPendingTotalRewards() internal view virtual returns (uint256 pendingTotalRewards);

    function _update() internal virtual returns (uint256 pendingTotalRewards);
}
