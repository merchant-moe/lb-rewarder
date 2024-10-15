// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LBHooksExtraRewarder} from "../rewarder/LBHooksExtraRewarder.sol";
import {LBHooksStatic} from "./LBHooksStatic.sol";

/**
 * @title LB Hooks Static Extra Rewarder
 * @dev Implementation of the LB Hooks Static Extra Rewarder
 */
contract LBHooksStaticExtraRewarder is LBHooksExtraRewarder, LBHooksStatic {
    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     */
    constructor(address lbHooksManager) LBHooksExtraRewarder(lbHooksManager) {}
}
