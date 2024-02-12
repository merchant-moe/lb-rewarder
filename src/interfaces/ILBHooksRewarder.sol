// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMasterChef} from "@moe-core/src/interfaces/IMasterChef.sol";
import {ILBHooksBaseRewarder} from "./ILBHooksBaseRewarder.sol";

interface ILBHooksRewarder is ILBHooksBaseRewarder {
    error LBHooksRewarder__NotNativeRewarder();

    function getPid() external view returns (uint256 pid);

    function getMasterChef() external view returns (IMasterChef masterChef);
}
