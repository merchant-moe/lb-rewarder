// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMasterChef} from "@moe-core/src/interfaces/IMasterChef.sol";
import {ILBHooksBaseRewarder} from "./ILBHooksBaseRewarder.sol";
import {ILBHooksExtraRewarder} from "./ILBHooksExtraRewarder.sol";

/**
 * @title LB Hooks Rewarder Interface
 * @dev Interface for the LB Hooks Rewarder
 */
interface ILBHooksMCRewarder is ILBHooksBaseRewarder {
    function getPid() external view returns (uint256 pid);

    function getMasterChef() external view returns (IMasterChef masterChef);
}
