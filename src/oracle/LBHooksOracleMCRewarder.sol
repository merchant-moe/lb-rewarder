// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LBHooksMCRewarder, IMasterChef, IERC20} from "../rewarder/LBHooksMCRewarder.sol";
import {LBHooksOracle} from "./LBHooksOracle.sol";

/**
 * @title LB Hooks Oracle MC Rewarder
 * @dev Implementation of the LB Hooks Oracle MC Rewarder
 */
contract LBHooksOracleMCRewarder is LBHooksMCRewarder, LBHooksOracle {
    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     * @param masterChef The address of the MasterChef contract
     * @param moe The address of the MOE token
     */
    constructor(address lbHooksManager, IMasterChef masterChef, IERC20 moe)
        LBHooksMCRewarder(lbHooksManager, masterChef, moe)
    {}
}
