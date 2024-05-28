// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILBHooksBaseRewarder} from "./ILBHooksBaseRewarder.sol";

/**
 * @title LB Hooks Parent Rewarder Interface
 * @dev Interface for the LB Hooks Parent Rewarder
 */
interface ILBHooksBaseParentRewarder is ILBHooksBaseRewarder {
    error LBHooksRewarder__InvalidLBHooksExtraRewarder();

    event LBHooksExtraRewarderSet(address lbHooksExtraRewarder);

    function getExtraHooksParameters() external view returns (bytes32 extraHooksParameters);

    function setLBHooksExtraRewarder(address lbHooksExtraRewarder, bytes calldata extraRewarderData) external;
}
