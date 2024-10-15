// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LBHooksExtraRewarder} from "../rewarder/LBHooksExtraRewarder.sol";
import {LBHooksDelta} from "./LBHooksDelta.sol";

/**
 * @title LB Hooks Delta Extra Rewarder
 * @dev Implementation of the LB Hooks Delta Extra Rewarder
 */
contract LBHooksDeltaExtraRewarder is LBHooksExtraRewarder, LBHooksDelta {
    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     */
    constructor(address lbHooksManager) LBHooksExtraRewarder(lbHooksManager) {}
}
