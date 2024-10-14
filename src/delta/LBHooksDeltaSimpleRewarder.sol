// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LBHooksSimpleRewarder} from "../rewarder/LBHooksSimpleRewarder.sol";
import {LBHooksDelta} from "./LBHooksDelta.sol";

/**
 * @title LB Hooks Delta Simple Rewarder
 * @dev Implementation of the LB Hooks Delta Simple Rewarder
 */
contract LBHooksDeltaSimpleRewarder is LBHooksSimpleRewarder, LBHooksDelta {
    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     */
    constructor(address lbHooksManager) LBHooksSimpleRewarder(lbHooksManager) {}
}
