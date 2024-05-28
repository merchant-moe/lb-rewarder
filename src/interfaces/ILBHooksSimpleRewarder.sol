// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILBHooksBaseSimpleRewarder} from "./ILBHooksBaseSimpleRewarder.sol";
import {ILBHooksBaseParentRewarder} from "./ILBHooksBaseParentRewarder.sol";

/**
 * @title LB Hooks Simple Rewarder Interface
 * @dev Interface for the LB Hooks Simple Rewarder
 */
interface ILBHooksSimpleRewarder is ILBHooksBaseSimpleRewarder, ILBHooksBaseParentRewarder {}
