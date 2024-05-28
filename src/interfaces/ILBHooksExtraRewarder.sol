// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILBHooksBaseRewarder} from "./ILBHooksBaseRewarder.sol";
import {ILBHooksMCRewarder} from "./ILBHooksMCRewarder.sol";

/**
 * @title LB Hooks Extra Rewarder Interface
 * @dev Interface for the LB Hooks Extra Rewarder
 */
interface ILBHooksExtraRewarder is ILBHooksBaseRewarder {
    error LBHooksExtraRewarder__InvalidStartTimestamp();
    error LBHooksExtraRewarder__InvalidDuration();
    error LBHooksExtraRewarder__ZeroReward();
    error LBHooksExtraRewarder__Stopped();
    error LBHooksExtraRewarder__UnauthorizedCaller();
    error LBHooksExtraRewarder__ParentRewarderNotLinked();

    event RewardParameterUpdated(uint256 rewardPerSecond, uint256 startTimestamp, uint256 endTimestamp);

    function getRemainingRewards() external view returns (uint256 remainingRewards);

    function getRewarderParameter()
        external
        view
        returns (uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp);

    function getParentRewarder() external view returns (ILBHooksMCRewarder);

    function setRewarderParameters(uint256 maxRewardPerSecond, uint256 startTimestamp, uint256 expectedDuration)
        external
        returns (uint256 rewardPerSecond);

    function setRewardPerSecond(uint256 maxRewardPerSecond, uint256 expectedDuration)
        external
        returns (uint256 rewardPerSecond);
}
