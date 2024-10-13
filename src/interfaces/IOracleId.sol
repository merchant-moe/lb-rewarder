// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Oracle Id Interface
 * @dev Interface for the Oracle Id
 */
interface IOracleId {
    function getLatestId() external view returns (uint24);
}
