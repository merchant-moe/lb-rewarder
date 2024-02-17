// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable//access/Ownable2StepUpgradeable.sol";
import {LBBaseHooks} from "@lb-protocol/src/LBBaseHooks.sol";
import {Uint256x256Math} from "@lb-protocol/src/libraries/math/Uint256x256Math.sol";
import {Clone} from "@lb-protocol/src/libraries/Clone.sol";
import {ILBPair} from "@lb-protocol/src/interfaces/ILBPair.sol";
import {PriceHelper} from "@lb-protocol/src/libraries/PriceHelper.sol";
import {BinHelper} from "@lb-protocol/src/libraries/BinHelper.sol";
import {Hooks} from "@lb-protocol/src/libraries/Hooks.sol";
import {ILBHooksBaseRewarder} from "./interfaces/ILBHooksBaseRewarder.sol";

abstract contract LBHooksBaseRewarder is LBBaseHooks, Ownable2StepUpgradeable, Clone, ILBHooksBaseRewarder {
    using Uint256x256Math for uint256;
    using SafeERC20 for IERC20;

    address public immutable implementation;

    int256 internal constant MAX_NUBER_OF_BINS = 11;
    uint8 internal constant OFFSET_PRECISION = 128;
    bytes32 internal constant FLAGS = Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_MINT_FLAG | Hooks.AFTER_MINT_FLAG
        | Hooks.BEFORE_BURN_FLAG | Hooks.AFTER_BURN_FLAG | Hooks.BEFORE_TRANSFER_FLAG | Hooks.AFTER_TRANSFER_FLAG;

    address internal immutable _lbHooksManager;

    int24 internal _deltaBinA;
    int24 internal _deltaBinB;

    uint256 internal _totalUnclaimedRewards;

    mapping(uint256 => Bin) internal _bins;
    mapping(address => uint256) internal _unclaimedRewards;

    constructor(address LBHooksManager) {
        implementation = address(this);

        _lbHooksManager = LBHooksManager;

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

    function getLBHooksManager() external view virtual returns (address) {
        return _lbHooksManager;
    }

    function isStopped() external view virtual returns (bool) {
        return !_isLinked();
    }

    // not safe if ids has duplicates
    function getPendingRewards(address user, uint256[] calldata ids) external view virtual returns (uint256) {
        if (!_isLinked()) return 0;

        ILBPair lbPair = _getLBPair();

        (uint256[] memory rewardedIds, uint24 activeId, uint256 binStart, uint256 binEnd) = _getRewardedRange();
        (uint256[] memory liquiditiesX128, uint256[] memory totalSuppliesX64, uint256 totalLiquiditiesX128) =
            _getLiquidityData(lbPair, activeId, rewardedIds);

        address user_ = user; // Avoid stack too deep error

        uint256 pendingTotalRewards = _getPendingTotalRewards();
        uint256 pendingRewards;

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

        return pendingRewards + _unclaimedRewards[user_];
    }

    function claim(address user, uint256[] calldata ids) external virtual {
        if (!_isLinked()) revert LBHooksBaseRewarder__UnlinkedHooks();
        if (!_isAuthorizedCaller(user)) revert LBHooksBaseRewarder__UnauthorizedCaller();

        _updateAccruedRewardsPerShare();
        _updateUser(user, ids);

        _onClaim(user, ids);

        _claim(user, _unclaimedRewards[user]);
    }

    function setDeltaBins(int24 deltaBinA, int24 deltaBinB) external virtual onlyOwner {
        if (deltaBinA > deltaBinB) revert LBHooksBaseRewarder__InvalidDeltaBins();
        if (int256(deltaBinB) - deltaBinA > MAX_NUBER_OF_BINS) revert LBHooksBaseRewarder__ExceedsMaxNumberOfBins();

        _updateAccruedRewardsPerShare();

        _deltaBinA = deltaBinA;
        _deltaBinB = deltaBinB;

        emit DeltaBinsSet(deltaBinA, deltaBinB);
    }

    function sweep(IERC20 token, address to) external virtual onlyOwner {
        uint256 balance = _balanceOfThis(token);

        if (balance == 0) revert LBHooksBaseRewarder__ZeroBalance();
        if (_isLinked() && token == _getRewardToken()) revert LBHooksBaseRewarder__LockedRewardToken();

        _safeTransfer(token, to, balance);
    }

    function _balanceOfThis(IERC20 token) internal view virtual returns (uint256) {
        return address(token) == address(0) ? address(this).balance : token.balanceOf(address(this));
    }

    function _getRewardToken() internal view virtual returns (IERC20) {
        return IERC20(_getArgAddress(20));
    }

    function _isAuthorizedCaller(address user) internal view virtual returns (bool) {
        return user == msg.sender;
    }

    function _getRewardedRange()
        internal
        view
        virtual
        returns (uint256[] memory rewardedIds, uint24 activeId, uint256 binStart, uint256 binEnd)
    {
        activeId = _getLBPair().getActiveId();
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

    function _getLiquidityData(ILBPair lbPair, uint24 activeId, uint256[] memory ids)
        internal
        view
        virtual
        returns (uint256[] memory liquiditiesX128, uint256[] memory totalSuppliesX64, uint256 totalLiquiditiesX128)
    {
        uint256 activePriceX128 = PriceHelper.getPriceFromId(activeId, lbPair.getBinStep());
        uint256 length = ids.length;

        liquiditiesX128 = new uint256[](length);
        totalSuppliesX64 = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            uint24 id = uint24(ids[i]);

            (uint128 binReserveX, uint128 binReserveY) = lbPair.getBin(id);

            uint256 totalSupplyX64 = lbPair.totalSupply(id);
            uint256 liquidityX128 = BinHelper.getLiquidity(binReserveX, binReserveY, activePriceX128);

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
        uint256 length = liquidityConfigs.length;

        ids = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            ids[i] = uint24(uint256(liquidityConfigs[i]));
        }
    }

    function _nativeReceived() internal view virtual {
        if (_getImmutableArgsOffset() != 0) revert LBHooksBaseRewarder__NotImplemented();
        if (address(_getRewardToken()) != address(0)) revert LBHooksBaseRewarder__NotNativeRewarder();
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

        (uint256[] memory ids, uint24 activeId,,) = _getRewardedRange();
        (uint256[] memory liquiditiesX128, uint256[] memory totalSuppliesX64, uint256 totalLiquiditiesX128) =
            _getLiquidityData(lbPair, activeId, ids);

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

    function _updateUser(address to, uint256[] memory ids) internal virtual {
        ILBPair lbPair = _getLBPair();

        uint256 length = ids.length;
        uint256 pendingRewards;
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

    function _getLBPair() internal view virtual override returns (ILBPair) {
        return ILBPair(_getArgAddress(0));
    }

    function _onHooksSet(bytes32 hooksParameters, bytes calldata data) internal override initializer {
        if (hooksParameters != Hooks.setHooks(FLAGS, address(this))) {
            revert LBHooksBaseRewarder__InvalidHooksParameters();
        }

        address owner = abi.decode(data, (address));
        __Ownable_init(owner);

        _onHooksSet(data);
    }

    function _beforeSwap(address, address, bool, bytes32) internal virtual override {
        _updateAccruedRewardsPerShare();
    }

    function _beforeMint(address, address to, bytes32[] calldata liquidityConfigs, bytes32) internal virtual override {
        _updateAccruedRewardsPerShare();
        _updateUser(to, _convertLiquidityConfigs(liquidityConfigs));
    }

    function _afterMint(address, address to, bytes32[] calldata, bytes32) internal virtual override {
        _claim(to, _unclaimedRewards[to]);
    }

    function _beforeBurn(address, address from, address, uint256[] calldata ids, uint256[] calldata)
        internal
        virtual
        override
    {
        _updateAccruedRewardsPerShare();
        _updateUser(from, ids);
    }

    function _afterBurn(address, address from, address, uint256[] calldata, uint256[] calldata)
        internal
        virtual
        override
    {
        _claim(from, _unclaimedRewards[from]);
    }

    function _beforeBatchTransferFrom(address, address from, address to, uint256[] calldata ids, uint256[] calldata)
        internal
        virtual
        override
    {
        _updateAccruedRewardsPerShare();

        _updateUser(from, ids);
        _updateUser(to, ids);
    }

    function _afterBatchTransferFrom(address, address from, address, uint256[] calldata, uint256[] calldata)
        internal
        virtual
        override
    {
        _claim(from, _unclaimedRewards[from]);
    }

    function _onHooksSet(bytes calldata data) internal virtual {}

    function _onClaim(address user, uint256[] calldata ids) internal virtual {}

    function _getPendingTotalRewards() internal view virtual returns (uint256 pendingTotalRewards);

    function _update() internal virtual returns (uint256 pendingTotalRewards);
}
