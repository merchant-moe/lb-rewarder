// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LBHooksSimpleRewarder} from "../rewarder/LBHooksSimpleRewarder.sol";
import {LBHooksOracle} from "./LBHooksOracle.sol";

contract LBHooksOracleSimpleRewarder is LBHooksSimpleRewarder, LBHooksOracle {
    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     */
    constructor(address lbHooksManager) LBHooksSimpleRewarder(lbHooksManager) {}
}
