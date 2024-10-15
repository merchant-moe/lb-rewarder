// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LBHooksBaseRewarder, Hooks} from "../base/LBHooksBaseRewarder.sol";
import {ILBHooksExtraRewarder} from "../interfaces/ILBHooksExtraRewarder.sol";
import {ILBHooksBaseParentRewarder} from "../interfaces/ILBHooksBaseParentRewarder.sol";
import {LBHooksBaseSimpleRewarder} from "../base/LBHooksBaseSimpleRewarder.sol";

import {TokenHelper} from "../library/TokenHelper.sol";

/**
 * @title LB Hooks Extra Rewarder
 * @dev This contract will be used as a second rewarder on top of the main rewarder to distribute a second token to the LPs
 * It will reward the LPs that are inside the range set in this contract
 */
abstract contract LBHooksExtraRewarder is LBHooksBaseSimpleRewarder, ILBHooksExtraRewarder {
    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     */
    constructor(address lbHooksManager) LBHooksBaseRewarder(lbHooksManager) {}

    /**
     * @dev Returns the parent rewarder
     * @return parentRewarder The parent rewarder
     */
    function getParentRewarder() external view virtual override returns (ILBHooksBaseParentRewarder) {
        return _getParentRewarder();
    }

    /**
     * @dev Internal function to return the parent rewarder
     * @return parentRewarder The parent rewarder
     */
    function _getParentRewarder() internal view virtual returns (ILBHooksBaseParentRewarder) {
        return ILBHooksBaseParentRewarder(_getArgAddress(40));
    }

    /**
     * @dev Overrides the internal function to check the caller to only allow the parent rewarder
     */
    function _checkTrustedCaller() internal view virtual override {
        if (address(_getParentRewarder()) != msg.sender) revert LBHooksExtraRewarder__UnauthorizedCaller();
    }

    /**
     * @dev Overrides the internal function to check if the rewarder is linked
     * Will return true if the parent rewarder has this contract as the extra rewarder
     * and if the parent rewarder is also linked
     * @return linked Whether the rewarder is linked
     */
    function _isLinked() internal view virtual override returns (bool linked) {
        ILBHooksBaseParentRewarder parentRewarder = _getParentRewarder();

        return Hooks.getHooks(parentRewarder.getExtraHooksParameters()) == address(this) && parentRewarder.isLinked();
    }

    /**
     * @dev Overrides the internal function to check if the caller is authorized
     * Will return true only if the caller is the parent rewarder
     * @return Whether the caller is the parent rewarder
     */
    function _isAuthorizedCaller(address) internal view virtual override returns (bool) {
        return msg.sender == address(_getParentRewarder());
    }

    /**
     * @dev Overrides the internal function that is called when the hooks are set to
     * check if the parent rewarder is linked to the LB pair
     */
    function _onHooksSet(bytes calldata) internal virtual override {
        if (Hooks.getHooks(_getLBPair().getLBHooksParameters()) != address(_getParentRewarder())) {
            revert LBHooksExtraRewarder__ParentRewarderNotLinked();
        }
    }

    /**
     * @dev Overrides the internal function that is called when the rewards are claimed
     */
    function _onClaim(address, uint256[] memory) internal virtual override {}
}
