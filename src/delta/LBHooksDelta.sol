// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../base/LBHooksRewarderVirtual.sol";

abstract contract LBHooksDelta is LBHooksRewarderVirtual {
    error LBHooksDelta__InvalidDeltaBins();

    event DeltaBinsSet(int24 deltaBinA, int24 deltaBinB);

    int24 internal _deltaBinA;
    int24 internal _deltaBinB;

    /**
     * @dev Sets the delta bins
     * The delta bins are used to determine the range of bins to be rewarded,
     * from [activeId + deltaBinA, activeId + deltaBinB[ (exclusive).
     * @param deltaBinA The delta bin A
     * @param deltaBinB The delta bin B
     */
    function setDeltaBins(int24 deltaBinA, int24 deltaBinB) external virtual onlyOwner {
        if (deltaBinA > deltaBinB) revert LBHooksDelta__InvalidDeltaBins();

        _updateAccruedRewardsPerShare();

        _deltaBinA = deltaBinA;
        _deltaBinB = deltaBinB;

        _getRewardedRange(); // Make sure that the constraints are respected

        emit DeltaBinsSet(deltaBinA, deltaBinB);
    }

    /**
     * @dev Returns the rewarded start and end id (exclusive)
     * @param activeId The active id
     * @return binStart The bin start to be rewarded
     * @return binEnd The bin end to be rewarded, exclusive
     */
    function _getRewardedBounds(uint24 activeId)
        internal
        view
        virtual
        override
        returns (uint256 binStart, uint256 binEnd)
    {
        (int24 deltaBinA, int24 deltaBinB) = (_deltaBinA, _deltaBinB);

        binStart = uint256(int256(uint256(activeId)) + deltaBinA);
        binEnd = uint256(int256(uint256(activeId)) + deltaBinB);
    }
}
