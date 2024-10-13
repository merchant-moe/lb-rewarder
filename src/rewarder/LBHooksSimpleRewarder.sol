// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Hooks} from "@lb-protocol/src/libraries/Hooks.sol";

import {LBHooksBaseSimpleRewarder} from "../base/LBHooksBaseSimpleRewarder.sol";
import {LBHooksBaseParentRewarder} from "../base/LBHooksBaseParentRewarder.sol";
import {LBHooksBaseRewarder} from "../base/LBHooksBaseRewarder.sol";
import {ILBHooksSimpleRewarder} from "../interfaces/ILBHooksSimpleRewarder.sol";

import {TokenHelper} from "../library/TokenHelper.sol";

/**
 * @title LB Hooks Simple Rewarder
 * @dev This contract allows to distribute rewards to LPs at a linear rate for a given duration
 * It can also have an extra rewarder to distribute a second token to the LPs
 * It will reward the LPs that are inside the range set in this contract
 */
contract LBHooksSimpleRewarder is LBHooksBaseSimpleRewarder, LBHooksBaseParentRewarder, ILBHooksSimpleRewarder {
    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     */
    constructor(address lbHooksManager) LBHooksBaseRewarder(lbHooksManager) {}

    function _onClaim(address user, uint256[] memory ids)
        internal
        virtual
        override(LBHooksBaseRewarder, LBHooksBaseParentRewarder)
    {
        LBHooksBaseParentRewarder._onClaim(user, ids);
    }

    function _beforeSwap(address sender, address to, bool swapForY, bytes32 amountsIn)
        internal
        virtual
        override(LBHooksBaseRewarder, LBHooksBaseParentRewarder)
    {
        LBHooksBaseParentRewarder._beforeSwap(sender, to, swapForY, amountsIn);
    }

    function _beforeMint(address from, address to, bytes32[] calldata liquidityConfigs, bytes32 amountsReceived)
        internal
        virtual
        override(LBHooksBaseRewarder, LBHooksBaseParentRewarder)
    {
        LBHooksBaseParentRewarder._beforeMint(from, to, liquidityConfigs, amountsReceived);
    }

    function _beforeBurn(
        address sender,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amountsToBurn
    ) internal virtual override(LBHooksBaseRewarder, LBHooksBaseParentRewarder) {
        LBHooksBaseParentRewarder._beforeBurn(sender, from, to, ids, amountsToBurn);
    }

    function _beforeBatchTransferFrom(
        address sender,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) internal virtual override(LBHooksBaseRewarder, LBHooksBaseParentRewarder) {
        LBHooksBaseParentRewarder._beforeBatchTransferFrom(sender, from, to, ids, amounts);
    }
}
