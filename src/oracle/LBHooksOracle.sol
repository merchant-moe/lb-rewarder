// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../base/LBHooksRewarderVirtual.sol";
import "../interfaces/IOracleId.sol";

/**
 * @title LB Hooks Oracle
 * @dev Abstract contract for the LB Hooks Oracle Rewarder
 * This contract allows to distribute rewards to LPs of the [oracleId + deltaBinA, oracleId + deltaBinB[ bins
 */
abstract contract LBHooksOracle is LBHooksRewarderVirtual {
    error LBHooksOracle__InvalidDeltaBins();

    event ParametersSet(address oracle, int24 deltaBinA, int24 deltaBinB);

    IOracleId internal _oracle;
    int24 internal _deltaBinA;
    int24 internal _deltaBinB;

    /**
     * @dev Returns the oracle parameters
     * @return oracle The oracle id address
     * @return deltaBinA The delta binA
     * @return deltaBinB The delta binB
     */
    function getParameters() external view returns (IOracleId oracle, int24 deltaBinA, int24 deltaBinB) {
        return (_oracle, _deltaBinA, _deltaBinB);
    }

    /**
     * @dev Sets the oracle and the delta bins
     * The delta bins are used to determine the range of bins to be rewarded,
     * from [oracleId + deltaBinA, oracleId + deltaBinB[ (exclusive).
     * @param oracle The oracle address
     * @param deltaBinA The delta bin A
     * @param deltaBinB The delta bin B
     */
    function setParameters(IOracleId oracle, int24 deltaBinA, int24 deltaBinB) external onlyOwner {
        if (deltaBinA > deltaBinB) revert LBHooksOracle__InvalidDeltaBins();

        _updateAccruedRewardsPerShare();

        _oracle = oracle;
        _deltaBinA = deltaBinA;
        _deltaBinB = deltaBinB;

        _getRewardedRange(); // Make sure that the constraints are respected

        emit ParametersSet(address(oracle), deltaBinA, deltaBinB);
    }

    /**
     * @dev Returns the rewarded start and end id (exclusive)
     * @return binStart The bin start to be rewarded
     * @return binEnd The bin end to be rewarded, exclusive
     */
    function _getRewardedBounds(uint24) internal view virtual override returns (uint256 binStart, uint256 binEnd) {
        (IOracleId oracle, int24 deltaBinA, int24 deltaBinB) = (_oracle, _deltaBinA, _deltaBinB);

        if (address(oracle) != address(0)) {
            uint24 oracleId = oracle.getLatestId();

            if (oracleId > 0) {
                binStart = uint256(int256(uint256(oracleId)) + deltaBinA);
                binEnd = uint256(int256(uint256(oracleId)) + deltaBinB);
            }
        }
    }
}
