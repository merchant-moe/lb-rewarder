// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LBHooksBaseRewarder} from "./LBHooksBaseRewarder.sol";
import {ILBHooksExtraRewarder} from "./interfaces/ILBHooksExtraRewarder.sol";

contract LBHooksExtraRewarder is LBHooksBaseRewarder, ILBHooksExtraRewarder {
    uint256 internal _rewardsPerSecond;
    uint256 internal _endTimestamp;
    uint256 internal _lastUpdateTimestamp;

    function getRewarderParameter()
        external
        view
        virtual
        returns (uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp)
    {
        return (_rewardsPerSecond, _lastUpdateTimestamp, _endTimestamp);
    }

    function getRemainingRewards() external view virtual returns (uint256 remainingRewards) {
        return _balanceOfThis(_getRewardToken()) - _totalUnclaimedRewards - _getPendingTotalRewards();
    }

    function getParentRewarder() external view virtual returns (address) {
        return _getParentRewarder();
    }

    function setRewarderParameters(uint256 maxRewardPerSecond, uint256 startTimestamp, uint256 expectedDuration)
        external
        virtual
        onlyOwner
        returns (uint256 rewardPerSecond)
    {
        return _setRewardParameters(maxRewardPerSecond, startTimestamp, expectedDuration);
    }

    function setRewardPerSecond(uint256 maxRewardPerSecond, uint256 expectedDuration)
        external
        virtual
        onlyOwner
        returns (uint256 rewardPerSecond)
    {
        uint256 lastUpdateTimestamp = _lastUpdateTimestamp;
        uint256 startTimestamp = lastUpdateTimestamp > block.timestamp ? lastUpdateTimestamp : block.timestamp;

        return _setRewardParameters(maxRewardPerSecond, startTimestamp, expectedDuration);
    }

    function _checkCaller() internal view virtual override {
        if (_getParentRewarder() != msg.sender) revert LBHooksExtraRewarder__UnauthorizedCaller();
    }

    function _getParentRewarder() internal view virtual returns (address) {
        return _getArgAddress(20);
    }

    function _getPendingTotalRewards() internal view virtual override returns (uint256 pendingTotalRewards) {
        uint256 lastUpdateTimestamp = _lastUpdateTimestamp;

        if (block.timestamp > lastUpdateTimestamp && block.timestamp < _endTimestamp) {
            pendingTotalRewards = _rewardsPerSecond * (block.timestamp - lastUpdateTimestamp);
        }
    }

    function _updateUser(address to, uint256[] memory ids) internal virtual override returns (uint256 pendingRewards) {
        pendingRewards = super._updateUser(to, ids);

        if (pendingRewards > 0) _totalUnclaimedRewards -= pendingRewards;
    }

    function _setRewardParameters(uint256 maxRewardPerSecond, uint256 startTimestamp, uint256 expectedDuration)
        internal
        virtual
        returns (uint256 rewardPerSecond)
    {
        if (startTimestamp < block.timestamp) revert LBHooksExtraRewarder__InvalidStartTimestamp(startTimestamp);
        if (!_isLinked()) revert LBHooksExtraRewarder__Stopped();
        if (expectedDuration == 0 && maxRewardPerSecond != 0) revert LBHooksExtraRewarder__InvalidDuration();

        _updateAccruedRewardsPerShare();

        uint256 remainingReward = _balanceOfThis(_getRewardToken()) - _totalUnclaimedRewards;
        uint256 maxExpectedReward = maxRewardPerSecond * expectedDuration;

        rewardPerSecond = maxExpectedReward > remainingReward ? remainingReward / expectedDuration : maxRewardPerSecond;
        uint256 expectedReward = rewardPerSecond * expectedDuration;

        if (expectedDuration != 0 && expectedReward == 0) revert LBHooksExtraRewarder__ZeroReward();

        uint256 endTimestamp = startTimestamp + expectedDuration;

        _rewardsPerSecond = rewardPerSecond;

        _endTimestamp = endTimestamp;

        if (startTimestamp != block.timestamp) _lastUpdateTimestamp = startTimestamp;

        emit RewardParameterUpdated(rewardPerSecond, startTimestamp, endTimestamp);
    }

    function _update() internal virtual override returns (uint256 pendingTotalRewards) {
        pendingTotalRewards = _getPendingTotalRewards();

        _totalUnclaimedRewards += pendingTotalRewards;

        if (block.timestamp > _lastUpdateTimestamp) _lastUpdateTimestamp = block.timestamp;
    }
}
