// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILBHooksBaseRewarder} from "./ILBHooksBaseRewarder.sol";

/**
 * @title LB Hooks Simple Rewarder Interface
 * @dev Interface for the LB Hooks Simple Rewarder
 */
interface ILBHooksBaseSimpleRewarder is ILBHooksBaseRewarder {
    error LBHooksBaseSimpleRewarder__InvalidStartTimestamp();
    error LBHooksBaseSimpleRewarder__InvalidDuration();
    error LBHooksBaseSimpleRewarder__ZeroReward();
    error LBHooksBaseSimpleRewarder__Stopped();

    event RewardParameterUpdated(uint256 rewardPerSecond, uint256 startTimestamp, uint256 endTimestamp);

    function getRewarderParameter()
        external
        view
        returns (uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp);

    function getRemainingRewards() external view returns (uint256 remainingRewards);

    function setRewarderParameters(uint256 maxRewardPerSecond, uint256 startTimestamp, uint256 expectedDuration)
        external
        returns (uint256 rewardPerSecond);

    function setRewardPerSecond(uint256 maxRewardPerSecond, uint256 expectedDuration)
        external
        returns (uint256 rewardPerSecond);
}
