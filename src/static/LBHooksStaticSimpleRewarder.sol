// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LBHooksSimpleRewarder} from "../rewarder/LBHooksSimpleRewarder.sol";
import {LBHooksStatic} from "./LBHooksStatic.sol";

/**
 * @title LB Hooks Static Simple Rewarder
 * @dev Implementation of the LB Hooks Static Simple Rewarder
 */
contract LBHooksStaticSimpleRewarder is LBHooksSimpleRewarder, LBHooksStatic {
    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     */
    constructor(address lbHooksManager) LBHooksSimpleRewarder(lbHooksManager) {}
}
