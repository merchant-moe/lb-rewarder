// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Hooks} from "@lb-protocol/src/libraries/Hooks.sol";

import {LBHooksBaseRewarder, ILBHooksBaseRewarder} from "./LBHooksBaseRewarder.sol";
import {ILBHooksBaseParentRewarder} from "../interfaces/ILBHooksBaseParentRewarder.sol";
import {ILBHooksExtraRewarder} from "../interfaces/ILBHooksExtraRewarder.sol";

/**
 * @title LB Hooks Base Parent Rewarder
 * @dev This contract allows to set a second rewarder that will be used to distribute a second token to the LPs
 */
abstract contract LBHooksBaseParentRewarder is LBHooksBaseRewarder, ILBHooksBaseParentRewarder {
    bytes32 internal _extraHooksParameters;

    /**
     * @dev Returns the extra hooks parameters
     * @return extraHooksParameters The extra hooks parameters
     */
    function getExtraHooksParameters() external view virtual override returns (bytes32 extraHooksParameters) {
        return _extraHooksParameters;
    }

    /**
     * @dev Sets the LB Hooks Extra Rewarder
     * @param lbHooksExtraRewarder The address of the LB Hooks Extra Rewarder
     * @param extraRewarderData The data to be used on the LB Hooks Extra Rewarder
     */
    function setLBHooksExtraRewarder(address lbHooksExtraRewarder, bytes calldata extraRewarderData)
        external
        virtual
        override
    {
        if (msg.sender != _lbHooksManager) _checkOwner();

        if (lbHooksExtraRewarder != address(0)) {
            bytes32 extraHooksParameters = Hooks.setHooks(FLAGS, lbHooksExtraRewarder);

            _extraHooksParameters = extraHooksParameters;

            if (
                ILBHooksExtraRewarder(lbHooksExtraRewarder).getLBPair() != _getLBPair()
                    || address(ILBHooksExtraRewarder(lbHooksExtraRewarder).getParentRewarder()) != address(this)
            ) {
                revert LBHooksRewarder__InvalidLBHooksExtraRewarder();
            }

            Hooks.onHooksSet(extraHooksParameters, extraRewarderData);
        } else {
            _extraHooksParameters = 0;
        }

        emit LBHooksExtraRewarderSet(lbHooksExtraRewarder);
    }

    /**
     * @dev Override the internal function that is called when the rewards are claimed
     * Will call the extra rewarder's claim function if the extra rewarder is set
     * @param user The address of the user
     * @param ids The ids of the LP tokens
     */
    function _onClaim(address user, uint256[] memory ids) internal virtual override {
        bytes32 extraHooksParameters = _extraHooksParameters;
        if (extraHooksParameters != 0) ILBHooksBaseRewarder(Hooks.getHooks(extraHooksParameters)).claim(user, ids);
    }

    /**
     * @dev Override the internal function that is called before a swap on the LB pair
     * Will call the extra rewarder's beforeSwap function if the extra rewarder is set
     * @param sender The address of the sender
     * @param to The address of the receiver
     * @param swapForY Whether the swap is for token Y
     * @param amountsIn The amounts in
     */
    function _beforeSwap(address sender, address to, bool swapForY, bytes32 amountsIn) internal virtual override {
        super._beforeSwap(sender, to, swapForY, amountsIn);

        Hooks.beforeSwap(_extraHooksParameters, sender, to, swapForY, amountsIn);
    }

    /**
     * @dev Override the internal function that is called before a mint on the LB pair
     * Will call the extra rewarder's beforeMint function if the extra rewarder is set
     * @param from The address of the sender
     * @param to The address of the receiver
     * @param liquidityConfigs The liquidity configs
     * @param amountsReceived The amounts received
     */
    function _beforeMint(address from, address to, bytes32[] calldata liquidityConfigs, bytes32 amountsReceived)
        internal
        virtual
        override
    {
        super._beforeMint(from, to, liquidityConfigs, amountsReceived);

        Hooks.beforeMint(_extraHooksParameters, from, to, liquidityConfigs, amountsReceived);
    }

    /**
     * @dev Override the internal function that is called before a burn on the LB pair
     * Will call the extra rewarder's beforeBurn function if the extra rewarder is set
     * @param sender The address of the sender
     * @param from The address of the sender
     * @param to The address of the receiver
     * @param ids The ids of the LP tokens
     * @param amountsToBurn The amounts to burn
     */
    function _beforeBurn(
        address sender,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amountsToBurn
    ) internal virtual override {
        super._beforeBurn(sender, from, to, ids, amountsToBurn);

        Hooks.beforeBurn(_extraHooksParameters, sender, from, to, ids, amountsToBurn);
    }

    /**
     * @dev Override the internal function that is called before a transfer on the LB pair
     * Will call the extra rewarder's beforeBatchTransferFrom function if the extra rewarder is set
     * @param sender The address of the sender
     * @param from The address of the sender
     * @param to The address of the receiver
     * @param ids The list of ids
     * @param amounts The list of amounts
     */
    function _beforeBatchTransferFrom(
        address sender,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) internal virtual override {
        super._beforeBatchTransferFrom(sender, from, to, ids, amounts);

        Hooks.beforeBatchTransferFrom(_extraHooksParameters, sender, from, to, ids, amounts);
    }
}
