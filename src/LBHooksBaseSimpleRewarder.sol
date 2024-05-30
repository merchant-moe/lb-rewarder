// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LBHooksBaseRewarder, Hooks} from "./LBHooksBaseRewarder.sol";
import {ILBHooksBaseSimpleRewarder} from "./interfaces/ILBHooksBaseSimpleRewarder.sol";

import {TokenHelper} from "./library/TokenHelper.sol";

/**
 * @title LB Hooks Base Simple Rewarder
 * @dev This contract allows to distribute rewards to LPs at a linear rate for a given duration
 * It will reward the LPs that are inside the range set in this contract
 */
abstract contract LBHooksBaseSimpleRewarder is LBHooksBaseRewarder, ILBHooksBaseSimpleRewarder {
    uint256 internal _rewardsPerSecond;
    uint256 internal _endTimestamp;
    uint256 internal _lastUpdateTimestamp;

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
        uint256 balance = TokenHelper.safeBalanceOf(_getRewardToken(), address(this));
        return balance - _totalUnclaimedRewards - _getPendingTotalRewards();
    }

    /**
     * @dev Sets the rewarder parameters
     * @param maxRewardPerSecond The maximum reward per second:
     * If the expected duration is 0 and the maxRewardPerSecond is 0, the rewarder will be stopped.
     * If the `maxRewardPerSecond * expectedDuration` is greater than the remaining rewards, the reward per second will be adjusted
     * to the remaining rewards divided by the expected duration.
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
     * @param maxRewardPerSecond The maximum reward per second:
     * If the expected duration is 0 and the maxRewardPerSecond is 0, the rewarder will be stopped.
     * If the `maxRewardPerSecond * expectedDuration` is greater than the remaining rewards, the reward per second will be adjusted
     * to the remaining rewards divided by the expected duration.
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
     * @dev Internal function to set the rewarder parameters
     * @param maxRewardPerSecond The maximum reward per second:
     * If the expected duration is 0 and the maxRewardPerSecond is 0, the rewarder will be stopped.
     * If the `maxRewardPerSecond * expectedDuration` is greater than the remaining rewards, the reward per second will be adjusted
     * to the remaining rewards divided by the expected duration.
     * @param startTimestamp The start timestamp
     * @param expectedDuration The expected duration
     * @return rewardPerSecond The reward per second
     */
    function _setRewardParameters(uint256 maxRewardPerSecond, uint256 startTimestamp, uint256 expectedDuration)
        internal
        virtual
        returns (uint256 rewardPerSecond)
    {
        if (startTimestamp < block.timestamp) revert LBHooksBaseSimpleRewarder__InvalidStartTimestamp();
        if (!_isLinked()) revert LBHooksBaseSimpleRewarder__Stopped();
        if ((expectedDuration == 0) != (maxRewardPerSecond == 0)) revert LBHooksBaseSimpleRewarder__InvalidDuration();

        _updateAccruedRewardsPerShare();

        uint256 remainingReward = TokenHelper.safeBalanceOf(_getRewardToken(), address(this)) - _totalUnclaimedRewards;
        uint256 maxExpectedReward = maxRewardPerSecond * expectedDuration;

        rewardPerSecond = maxExpectedReward > remainingReward ? remainingReward / expectedDuration : maxRewardPerSecond;
        uint256 expectedReward = rewardPerSecond * expectedDuration;

        if (expectedDuration != 0 && expectedReward == 0) revert LBHooksBaseSimpleRewarder__ZeroReward();

        uint256 endTimestamp = startTimestamp + expectedDuration;

        _rewardsPerSecond = rewardPerSecond;

        _endTimestamp = endTimestamp;
        _lastUpdateTimestamp = startTimestamp;

        emit RewardParameterUpdated(rewardPerSecond, startTimestamp, endTimestamp);
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
     * @dev Overrides the internal function to update the rewards
     * @return pendingTotalRewards The pending total rewards
     */
    function _updateRewards() internal virtual override returns (uint256 pendingTotalRewards) {
        pendingTotalRewards = _getPendingTotalRewards();

        if (block.timestamp > _lastUpdateTimestamp) _lastUpdateTimestamp = block.timestamp;
    }
}
