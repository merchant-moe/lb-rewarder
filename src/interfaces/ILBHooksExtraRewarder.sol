// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILBHooksBaseSimpleRewarder} from "./ILBHooksBaseSimpleRewarder.sol";
import {ILBHooksBaseParentRewarder} from "./ILBHooksBaseParentRewarder.sol";

/**
 * @title LB Hooks Extra Rewarder Interface
 * @dev Interface for the LB Hooks Extra Rewarder
 */
interface ILBHooksExtraRewarder is ILBHooksBaseSimpleRewarder {
    error LBHooksExtraRewarder__UnauthorizedCaller();
    error LBHooksExtraRewarder__ParentRewarderNotLinked();

    function getParentRewarder() external view returns (ILBHooksBaseParentRewarder);
}
