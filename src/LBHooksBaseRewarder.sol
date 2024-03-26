// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
import {SafeCast} from "@lb-protocol/src/libraries/math/SafeCast.sol";

import {ILBHooksBaseRewarder} from "./interfaces/ILBHooksBaseRewarder.sol";
import {TokenHelper, IERC20} from "./library/TokenHelper.sol";

/**
 * @title LB Hooks Base Rewarder
 * @dev Base contract for any LB Hooks Rewarder
 */
abstract contract LBHooksBaseRewarder is LBBaseHooks, Ownable2StepUpgradeable, Clone, ILBHooksBaseRewarder {
    using Uint256x256Math for uint256;
    using SafeCast for uint256;

    address public immutable implementation;

    int256 internal constant MAX_NUMBER_OF_BINS = 11;
    uint8 internal constant OFFSET_PRECISION = 128;
    bytes32 internal constant FLAGS = Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_MINT_FLAG | Hooks.AFTER_MINT_FLAG
        | Hooks.BEFORE_BURN_FLAG | Hooks.AFTER_BURN_FLAG | Hooks.BEFORE_TRANSFER_FLAG | Hooks.AFTER_TRANSFER_FLAG;

    address internal immutable _lbHooksManager;

    int24 internal _deltaBinA;
    int24 internal _deltaBinB;

    uint256 internal _totalUnclaimedRewards;

    mapping(uint256 => Bin) internal _bins;
    mapping(address => uint256) internal _unclaimedRewards;

    /**
     * @dev Constructor of the contract
     * @param LBHooksManager The address of the LBHooksManager contract
     */
    constructor(address LBHooksManager) {
        implementation = address(this);

        _lbHooksManager = LBHooksManager;

        _disableInitializers();
    }

    /**
     * @dev Receive function called when the contract receives native tokens
     */
    receive() external payable {
        _nativeReceived();
    }

    /**
     * @dev Fallback function called when the contract receives native tokens
     */
    fallback() external payable {
        _nativeReceived();
    }

    /**
     * @dev Returns the reward token
     * @return rewardToken The reward token
     */
    function getRewardToken() external view virtual override returns (IERC20) {
        return _getRewardToken();
    }

    /**
     * @dev Returns the LB Hooks Manager
     * @return lbHooksManager The LB Hooks Manager
     */
    function getLBHooksManager() external view virtual override returns (address) {
        return _lbHooksManager;
    }

    /**
     * @dev Returns whether the rewarder is stopped
     * @return isStopped Whether the rewarder is stopped
     */
    function isStopped() external view virtual override returns (bool) {
        return !_isLinked();
    }

    /**
     * @dev Returns the rewarded range from [binStart, binEnd[ (exclusive)
     * @return binStart The bin start to be rewarded
     * @return binEnd The bin end to be rewarded, exclusive
     */
    function getRewardedRange() external view virtual override returns (uint256 binStart, uint256 binEnd) {
        (,, binStart, binEnd) = _getRewardedRange();
    }

    /**
     * @dev Returns the pending rewards for the given user and ids
     * The ids are expected to be unique, if they are not, the rewards returned might be greater than expected
     * @param user The address of the user
     * @param ids The ids of the bins
     * @return pendingRewards The pending rewards
     */
    function getPendingRewards(address user, uint256[] calldata ids) external view virtual override returns (uint256) {
        if (!_isLinked()) return 0;

        uint256[] calldata ids_ = ids; // Avoid stack too deep error

        ILBPair lbPair = _getLBPair();

        (uint256[] memory rewardedIds, uint24 activeId, uint256 binStart, uint256 binEnd) = _getRewardedRange();
        (uint256[] memory liquiditiesX128, uint256[] memory totalSuppliesX64, uint256 totalLiquiditiesX128) =
            _getLiquidityData(lbPair, activeId, rewardedIds);

        address user_ = user; // Avoid stack too deep error

        uint256 pendingTotalRewards = _getPendingTotalRewards();
        uint256 pendingRewards;

        for (uint256 i; i < ids_.length; ++i) {
            uint24 id = ids_[i].safe24();

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

    /**
     * @dev Claims the rewards for the given user and ids
     * @param user The address of the user
     * @param ids The ids of the bins
     */
    function claim(address user, uint256[] calldata ids) external virtual override {
        if (!_isLinked()) revert LBHooksBaseRewarder__UnlinkedHooks();
        if (!_isAuthorizedCaller(user)) revert LBHooksBaseRewarder__UnauthorizedCaller();

        _updateAccruedRewardsPerShare();
        _updateUser(user, ids);

        _claim(user, ids, _unclaimedRewards[user]);
    }

    /**
     * @dev Sets the delta bins
     * The delta bins are used to determine the range of bins to be rewarded,
     * from [activeId + deltaBinA, activeId + deltaBinB[ (exclusive).
     * @param deltaBinA The delta bin A
     * @param deltaBinB The delta bin B
     */
    function setDeltaBins(int24 deltaBinA, int24 deltaBinB) external virtual override onlyOwner {
        if (deltaBinA > deltaBinB) revert LBHooksBaseRewarder__InvalidDeltaBins();
        if (int256(deltaBinB) - deltaBinA > MAX_NUMBER_OF_BINS) revert LBHooksBaseRewarder__ExceedsMaxNumberOfBins();

        _updateAccruedRewardsPerShare();

        _deltaBinA = deltaBinA;
        _deltaBinB = deltaBinB;

        emit DeltaBinsSet(deltaBinA, deltaBinB);
    }

    /**
     * @dev Sweeps the given token to the given address
     * @param token The address of the token
     * @param to The address of the recipient
     */
    function sweep(IERC20 token, address to) external virtual override onlyOwner {
        uint256 balance = TokenHelper.safeBalanceOf(token, address(this));

        if (balance == 0) revert LBHooksBaseRewarder__ZeroBalance();
        if (_isLinked() && token == _getRewardToken()) revert LBHooksBaseRewarder__LockedRewardToken();

        TokenHelper.safeTransfer(token, to, balance);
    }

    /**
     * @dev Internal function to return the reward token
     * @return The reward token
     */
    function _getRewardToken() internal view virtual returns (IERC20) {
        return IERC20(_getArgAddress(20));
    }

    /**
     * @dev Internal function to return whether caller is the msg.sender
     * @param user The address of the user
     * @return Whether the caller is the msg.sender
     */
    function _isAuthorizedCaller(address user) internal view virtual returns (bool) {
        return user == msg.sender;
    }

    /**
     * @dev Internal helper function to return the rewarded range
     * @return rewardedIds The list of the rewarded ids from binStart to binEnd
     * @return activeId The active id
     * @return binStart The bin start to be rewarded
     * @return binEnd The bin end to be rewarded
     */
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
                rewardedIds[i] = (binStart + i).safe24();
            }
        }
    }

    /**
     * @dev Internal function to return the liquidity data for the given ids
     * @param lbPair The LB Pair
     * @param activeId The active id
     * @param ids The ids of the bins
     * @return liquiditiesX128 The liquidities for the given ids
     * @return totalSuppliesX64 The total supplies for the given ids
     * @return totalLiquiditiesX128 The total liquidities for the given ids
     */
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
            uint24 id = ids[i].safe24();

            (uint128 binReserveX, uint128 binReserveY) = lbPair.getBin(id);

            uint256 totalSupplyX64 = lbPair.totalSupply(id);
            uint256 liquidityX128 = BinHelper.getLiquidity(binReserveX, binReserveY, activePriceX128);

            liquiditiesX128[i] = liquidityX128;
            totalSuppliesX64[i] = totalSupplyX64;

            totalLiquiditiesX128 += liquidityX128;
        }
    }

    /**
     * @dev Internal function to convert the liquidity configs to ids
     * @param liquidityConfigs The liquidity configs
     * @return ids The ids
     */
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

    /**
     * @dev Internal function that allows the rewarder to receive native tokens only
     * if the rewarded token is native, else it will revert
     */
    function _nativeReceived() internal view virtual {
        if (_getImmutableArgsOffset() != 0) revert LBHooksBaseRewarder__NotImplemented();
        if (address(_getRewardToken()) != address(0)) revert LBHooksBaseRewarder__NotNativeRewarder();
    }

    /**
     * @dev Internal function to update the accrued rewards per share
     */
    function _updateAccruedRewardsPerShare() internal virtual {
        uint256 pendingTotalRewards = _updateRewards();

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

    /**
     * @dev Internal function to update the user
     * @param to The address of the user
     * @param ids The ids of the bins
     */
    function _updateUser(address to, uint256[] memory ids) internal virtual {
        ILBPair lbPair = _getLBPair();

        uint256 length = ids.length;
        uint256 pendingRewards;
        for (uint256 i; i < length; ++i) {
            uint24 id = ids[i].safe24();
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

    /**
     * @dev Internal function to claim the rewards for the given user
     * @param user The address of the user
     * @param ids The ids of the bins
     * @param rewards The rewards to claim
     */
    function _claim(address user, uint256[] memory ids, uint256 rewards) internal virtual {
        if (rewards == 0) return;

        _totalUnclaimedRewards -= rewards;
        _unclaimedRewards[user] -= rewards;

        _onClaim(user, ids);

        TokenHelper.safeTransfer(_getRewardToken(), user, rewards);
    }

    /**
     * @dev Override the internal function to return the LB Pair
     * @return lbPair The LB Pair
     */
    function _getLBPair() internal view virtual override returns (ILBPair) {
        return ILBPair(_getArgAddress(0));
    }

    /**
     * @dev Override the internal function that is called when the rewarder is set
     * Will revert if the rewarder is already linked via the inializer modifier
     * Will revert if the hooks parameters are not the expected ones
     * @param hooksParameters The hooks parameters
     * @param data The data used to initialize the rewarder; should at least contain the ABI encoded address of the owner
     */
    function _onHooksSet(bytes32 hooksParameters, bytes calldata data) internal override initializer {
        if (hooksParameters != Hooks.setHooks(FLAGS, address(this))) {
            revert LBHooksBaseRewarder__InvalidHooksParameters();
        }

        address owner = abi.decode(data, (address));
        __Ownable_init(owner);

        _onHooksSet(data);
    }

    /**
     * @dev Override the internal function that is called before a swap on the LB Pair
     * Will update the accrued rewards per share
     */
    function _beforeSwap(address, address, bool, bytes32) internal virtual override {
        _updateAccruedRewardsPerShare();
    }

    /**
     * @dev Override the internal function that is called before a mint on the LB Pair
     * Will update the accrued rewards per share and the user rewards
     * @param to The address of the recipient of the LB Pair tokens
     * @param liquidityConfigs The liquidity configs
     */
    function _beforeMint(address, address to, bytes32[] calldata liquidityConfigs, bytes32) internal virtual override {
        _updateAccruedRewardsPerShare();
        _updateUser(to, _convertLiquidityConfigs(liquidityConfigs));
    }

    /**
     * @dev Override the internal function that is called before a burn on the LB Pair
     * Will update the accrued rewards per share and the user rewards
     * @param from The address of the sender of the LB Pair tokens
     * @param ids The ids of the bins
     */
    function _beforeBurn(address, address from, address, uint256[] calldata ids, uint256[] calldata)
        internal
        virtual
        override
    {
        _updateAccruedRewardsPerShare();
        _updateUser(from, ids);
    }

    /**
     * @dev Override the internal function that is called before a transfer on the LB Pair
     * Will update the accrued rewards per share and both the sender and recipient rewards
     * @param from The address of the sender of the LB Pair tokens
     * @param to The address of the recipient of the LB Pair tokens
     * @param ids The ids of the bins
     */
    function _beforeBatchTransferFrom(address, address from, address to, uint256[] calldata ids, uint256[] calldata)
        internal
        virtual
        override
    {
        _updateAccruedRewardsPerShare();

        _updateUser(from, ids);
        _updateUser(to, ids);
    }

    /**
     * @dev Internal function that can be overriden to add custom logic when the rewarder is set
     * @param data The data used to initialize the rewarder
     */
    function _onHooksSet(bytes calldata data) internal virtual {}

    /**
     * @dev Internal function that can be overriden to add custom logic when the rewards are claimed
     * @param user The address of the user
     * @param ids The ids of the bins
     */
    function _onClaim(address user, uint256[] memory ids) internal virtual {}

    /**
     * @dev Internal function that **MUST** be overriden to return the total pending rewards
     * @return pendingTotalRewards The total pending rewards
     */
    function _getPendingTotalRewards() internal view virtual returns (uint256 pendingTotalRewards);

    /**
     * @dev Internal function that **MUST** be overriden to update and return the total pending rewards
     * @return pendingTotalRewards The total pending rewards
     */
    function _updateRewards() internal virtual returns (uint256 pendingTotalRewards);
}
