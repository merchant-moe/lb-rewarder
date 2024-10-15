// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LBHooksMCRewarder, IMasterChef, IERC20} from "../rewarder/LBHooksMCRewarder.sol";
import {LBHooksDelta} from "./LBHooksDelta.sol";

/**
 * @title LB Hooks Delta MC Rewarder
 * @dev Implementation of the LB Hooks Delta MC Rewarder
 */
contract LBHooksDeltaMCRewarder is LBHooksMCRewarder, LBHooksDelta {
    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     */
    constructor(address lbHooksManager, IMasterChef masterChef, IERC20 moe)
        LBHooksMCRewarder(lbHooksManager, masterChef, moe)
    {}
}
