// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LBHooksBaseRewarder, Hooks} from "./LBHooksBaseRewarder.sol";
import {ILBHooksExtraRewarder} from "./interfaces/ILBHooksExtraRewarder.sol";
import {ILBHooksRewarder} from "./interfaces/ILBHooksRewarder.sol";

/**
 * @title LB Hooks Extra Rewarder
 * @dev This contract will be used as a second rewarder on top of the main rewarder to distribute a second token to the LPs
 * It will reward the LPs that are inside the range set in this contract
 */
contract LBHooksExtraRewarder is LBHooksBaseRewarder, ILBHooksExtraRewarder {
    uint256 internal _rewardsPerSecond;
    uint256 internal _endTimestamp;
    uint256 internal _lastUpdateTimestamp;

    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     */
    constructor(address lbHooksManager) LBHooksBaseRewarder(lbHooksManager) {}

    /**
     * @dev Returns the rewarder parameters
     * @return rewardPerSecond The reward per second
     * @return lastUpdateTimestamp The last update timestamp
     * @return endTimestamp The end timestamp
     */
    function getRewarderParameter()
        external
        view
        virtual
        override
        returns (uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp)
    {
        return (_rewardsPerSecond, _lastUpdateTimestamp, _endTimestamp);
    }

    /**
     * @dev Returns the remaining rewards
     * @return remainingRewards The remaining rewards
     */
    function getRemainingRewards() external view virtual override returns (uint256 remainingRewards) {
        return _balanceOfThis(_getRewardToken()) - _totalUnclaimedRewards - _getPendingTotalRewards();
    }

    /**
     * @dev Returns the parent rewarder
     * @return parentRewarder The parent rewarder
     */
    function getParentRewarder() external view virtual override returns (ILBHooksRewarder) {
        return _getParentRewarder();
    }

    /**
     * @dev Sets the rewarder parameters
     * @param maxRewardPerSecond The maximum reward per second
     * @param startTimestamp The start timestamp
     * @param expectedDuration The expected duration
     * @return rewardPerSecond The reward per second
     */
    function setRewarderParameters(uint256 maxRewardPerSecond, uint256 startTimestamp, uint256 expectedDuration)
        external
        virtual
        override
        onlyOwner
        returns (uint256 rewardPerSecond)
    {
        return _setRewardParameters(maxRewardPerSecond, startTimestamp, expectedDuration);
    }

    /**
     * @dev Sets the reward per second
     * @param maxRewardPerSecond The maximum reward per second
     * @param expectedDuration The expected duration
     * @return rewardPerSecond The reward per second
     */
    function setRewardPerSecond(uint256 maxRewardPerSecond, uint256 expectedDuration)
        external
        virtual
        override
        onlyOwner
        returns (uint256 rewardPerSecond)
    {
        uint256 lastUpdateTimestamp = _lastUpdateTimestamp;
        uint256 startTimestamp = lastUpdateTimestamp > block.timestamp ? lastUpdateTimestamp : block.timestamp;

        return _setRewardParameters(maxRewardPerSecond, startTimestamp, expectedDuration);
    }

    /**
     * @dev Internal function to return the parent rewarder
     * @return parentRewarder The parent rewarder
     */
    function _getParentRewarder() internal view virtual returns (ILBHooksRewarder) {
        return ILBHooksRewarder(_getArgAddress(40));
    }

    /**
     * @dev Internal function to set the rewarder parameters
     * @param maxRewardPerSecond The maximum reward per second
     * @param startTimestamp The start timestamp
     * @param expectedDuration The expected duration
     * @return rewardPerSecond The reward per second
     */
    function _setRewardParameters(uint256 maxRewardPerSecond, uint256 startTimestamp, uint256 expectedDuration)
        internal
        virtual
        returns (uint256 rewardPerSecond)
    {
        if (startTimestamp < block.timestamp) revert LBHooksExtraRewarder__InvalidStartTimestamp();
        if (!_isLinked()) revert LBHooksExtraRewarder__Stopped();
        if ((expectedDuration == 0) != (maxRewardPerSecond == 0)) revert LBHooksExtraRewarder__InvalidDuration();

        _updateAccruedRewardsPerShare();

        uint256 remainingReward = _balanceOfThis(_getRewardToken()) - _totalUnclaimedRewards;
        uint256 maxExpectedReward = maxRewardPerSecond * expectedDuration;

        rewardPerSecond = maxExpectedReward > remainingReward ? remainingReward / expectedDuration : maxRewardPerSecond;
        uint256 expectedReward = rewardPerSecond * expectedDuration;

        if (expectedDuration != 0 && expectedReward == 0) revert LBHooksExtraRewarder__ZeroReward();

        uint256 endTimestamp = startTimestamp + expectedDuration;

        _rewardsPerSecond = rewardPerSecond;

        _endTimestamp = endTimestamp;
        _lastUpdateTimestamp = startTimestamp;

        emit RewardParameterUpdated(rewardPerSecond, startTimestamp, endTimestamp);
    }

    /**
     * @dev Overrides the internal function to check the caller to only allow the parent rewarder
     */
    function _checkTrustedCaller() internal view virtual override {
        if (address(_getParentRewarder()) != msg.sender) revert LBHooksExtraRewarder__UnauthorizedCaller();
    }

    /**
     * @dev Overrides the internal function to check if the rewarder is linked
     * Will return true if the parent rewarder has this contract as the extra rewarder
     * and if the parent rewarder is also linked
     * @return linked Whether the rewarder is linked
     */
    function _isLinked() internal view virtual override returns (bool linked) {
        ILBHooksRewarder parentRewarder = _getParentRewarder();

        return Hooks.getHooks(parentRewarder.getExtraHooksParameters()) == address(this) && parentRewarder.isLinked();
    }

    /**
     * @dev Overrides the internal function to check if the caller is authorized
     * Will return true only if the caller is the parent rewarder
     * @return Whether the caller is the parent rewarder
     */
    function _isAuthorizedCaller(address) internal view virtual override returns (bool) {
        return msg.sender == address(_getParentRewarder());
    }

    /**
     * @dev Overrides the internal function to return the pending total rewards
     * Will return the rewards per second multiplied by the delta timestamp
     * @return pendingTotalRewards The pending total rewards
     */
    function _getPendingTotalRewards() internal view virtual override returns (uint256 pendingTotalRewards) {
        uint256 lastUpdateTimestamp = _lastUpdateTimestamp;

        if (block.timestamp > lastUpdateTimestamp) {
            uint256 endTimestamp = _endTimestamp;

            if (endTimestamp <= lastUpdateTimestamp) return 0;

            uint256 deltaTimestamp = block.timestamp < endTimestamp
                ? block.timestamp - lastUpdateTimestamp
                : endTimestamp - lastUpdateTimestamp;

            pendingTotalRewards = _rewardsPerSecond * deltaTimestamp;
        }
    }

    /**
     * @dev Overrides the internal function that is called when the hooks are set to
     * check if the parent rewarder is linked to the LB pair
     */
    function _onHooksSet(bytes calldata) internal virtual override {
        if (Hooks.getHooks(_getLBPair().getLBHooksParameters()) != address(_getParentRewarder())) {
            revert LBHooksExtraRewarder__ParentRewarderNotLinked();
        }
    }

    /**
     * @dev Overrides the internal function to update the rewards
     * @return pendingTotalRewards The pending total rewards
     */
    function _updateRewards() internal virtual override returns (uint256 pendingTotalRewards) {
        pendingTotalRewards = _getPendingTotalRewards();

        if (block.timestamp > _lastUpdateTimestamp) _lastUpdateTimestamp = block.timestamp;
    }
}
