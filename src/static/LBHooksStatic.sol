// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../base/LBHooksRewarderVirtual.sol";

/**
 * @title LB Hooks Static Rewarder
 * @dev Abstract contract for the LB Hooks Static Rewarder
 * This contract allows to distribute rewards to LPs of the [binStart, binEnd[ bins
 */
abstract contract LBHooksStatic is LBHooksRewarderVirtual {
    error LBHooksStatic__InvalidBins();

    event BinRangeSet(uint24 binStart, uint24 binEnd);

    uint24 internal _binStart;
    uint24 internal _binEnd;

    /**
     * @dev Returns the range of bins to be rewarded
     * @return binStart The bin start to be rewarded
     * @return binEnd The bin end to be rewarded, exclusive
     */
    function getParameters() external view returns (uint24 binStart, uint24 binEnd) {
        return (_binStart, _binEnd);
    }

    /**
     * @dev Sets the range of bins to be rewarded
     * @param binStart The bin start to be rewarded
     * @param binEnd The bin end to be rewarded, exclusive
     */
    function setRange(uint24 binStart, uint24 binEnd) external onlyOwner {
        if (binStart > binEnd) revert LBHooksStatic__InvalidBins();

        _updateAccruedRewardsPerShare();

        _binStart = binStart;
        _binEnd = binEnd;

        _getRewardedRange(); // Make sure that the constraints are respected

        emit BinRangeSet(binStart, binEnd);
    }

    /**
     * @dev Returns the rewarded start and end id (exclusive)
     * @return binStart The bin start to be rewarded
     * @return binEnd The bin end to be rewarded, exclusive
     */
    function _getRewardedBounds(uint24) internal view virtual override returns (uint256 binStart, uint256 binEnd) {
        return (uint256(_binStart), uint256(_binEnd));
    }
}
