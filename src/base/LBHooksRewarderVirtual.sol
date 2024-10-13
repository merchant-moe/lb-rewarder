// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

abstract contract LBHooksRewarderVirtual is Ownable2StepUpgradeable {
    /**
     * @dev Internal function that can be overriden to add custom logic when the rewarder is set
     * @param data The data used to initialize the rewarder
     */
    function _onHooksSet(bytes calldata data) internal virtual;

    /**
     * @dev Internal function that can be overriden to add custom logic when the rewards are claimed
     * @param user The address of the user
     * @param ids The ids of the bins
     */
    function _onClaim(address user, uint256[] memory ids) internal virtual;

    /**
     * @dev Internal function that **MUST** be overriden to return the total pending rewards
     * @return pendingTotalRewards The total pending rewards
     */
    function _getPendingTotalRewards() internal view virtual returns (uint256 pendingTotalRewards);

    /**
     * @dev Internal function that **MUST** be overriden to return the rewarded start and end id (exclusive)
     * @param activeId The active id
     * @return binStart The bin start to be rewarded
     * @return binEnd The bin end to be rewarded, exclusive
     */
    function _getRewardedBounds(uint24 activeId) internal view virtual returns (uint256 binStart, uint256 binEnd);

    /**
     * @dev Internal helper function that **MUST** be overriden to return the rewarded range
     * @return rewardedIds The list of the rewarded ids from binStart to binEnd
     * @return activeId The active id
     * @return binStart The bin start to be rewarded
     * @return binEnd The bin end to be rewarded
     */
    function _getRewardedRange()
        internal
        view
        virtual
        returns (uint256[] memory rewardedIds, uint24 activeId, uint256 binStart, uint256 binEnd);

    /**
     * @dev Internal function that **MUST** be overriden to update and return the total pending rewards
     * @return pendingTotalRewards The total pending rewards
     */
    function _updateRewards() internal virtual returns (uint256 pendingTotalRewards);

    /**
     * @dev Internal function that **MUST** be overriden to update the accrued rewards per share
     * @dev Internal function to update the accrued rewards per share
     */
    function _updateAccruedRewardsPerShare() internal virtual;
}
