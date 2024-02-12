// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILBHooksBaseRewarder} from "./ILBHooksBaseRewarder.sol";

interface ILBHooksExtraRewarder is ILBHooksBaseRewarder {
    error LBHooksExtraRewarder__InvalidStartTimestamp(uint256 startTimestamp);
    error LBHooksExtraRewarder__InvalidDuration();
    error LBHooksExtraRewarder__ZeroReward();
    error LBHooksExtraRewarder__Stopped();
    error LBHooksExtraRewarder__UnauthorizedCaller();

    event RewardParameterUpdated(uint256 rewardPerSecond, uint256 startTimestamp, uint256 endTimestamp);

    function getRemainingRewards() external view returns (uint256 remainingRewards);

    function getParentRewarder() external view returns (address);

    function setRewarderParameters(uint256 maxRewardPerSecond, uint256 startTimestamp, uint256 expectedDuration)
        external
        returns (uint256 rewardPerSecond);

    function setRewardPerSecond(uint256 maxRewardPerSecond, uint256 expectedDuration)
        external
        returns (uint256 rewardPerSecond);
}
