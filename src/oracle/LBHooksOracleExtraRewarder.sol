// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LBHooksExtraRewarder} from "../rewarder/LBHooksExtraRewarder.sol";
import {LBHooksOracle} from "./LBHooksOracle.sol";

contract LBHooksOracleExtraRewarder is LBHooksExtraRewarder, LBHooksOracle {
    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     */
    constructor(address lbHooksManager) LBHooksExtraRewarder(lbHooksManager) {}
}
