// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IMasterChef, IMasterChefRewarder} from "@moe-core/src/interfaces/IMasterChef.sol";
import {LBHooksBaseParentRewarder, LBHooksBaseRewarder} from "../base/LBHooksBaseParentRewarder.sol";
import {ILBHooksMCRewarder} from "../interfaces/ILBHooksMCRewarder.sol";

import {TokenHelper} from "../library/TokenHelper.sol";

/**
 * @title LB Hooks MasterChef Rewarder
 * @dev Main contract for the LB Hooks Rewarder
 * This contract will be used as a sink on the masterchef to receive MOE rewards and distribute them to the LPs
 * It can also have an extra rewarder to distribute a second token to the LPs
 * It will reward the LPs that are inside the range set in this contract
 */
contract LBHooksMCRewarder is LBHooksBaseParentRewarder, ERC20Upgradeable, ILBHooksMCRewarder {
    IMasterChef internal immutable _masterChef;
    IERC20 internal immutable _moe;

    /**
     * @dev Constructor of the contract
     * @param lbHooksManager The address of the LBHooksManager contract
     * @param masterChef The address of the MasterChef contract
     * @param moe The address of the MOE token
     */
    constructor(address lbHooksManager, IMasterChef masterChef, IERC20 moe) LBHooksBaseRewarder(lbHooksManager) {
        _masterChef = masterChef;
        _moe = moe;
    }

    /**
     * @dev Returns the pool id used to reward the LPs
     * @return pid The pool id
     */
    function getPid() external view virtual override returns (uint256 pid) {
        return _getPid();
    }

    /**
     * @dev Returns the MasterChef contract
     * @return masterChef The MasterChef contract
     */
    function getMasterChef() external view virtual override returns (IMasterChef masterChef) {
        return _masterChef;
    }

    /**
     * @dev Internal function to get the pool id used to reward the LPs
     * @return pid The pool id
     */
    function _getPid() internal pure virtual returns (uint256 pid) {
        return _getArgUint256(20);
    }

    /**
     * @dev Override the internal function to get the reward token as it's always the MOE token
     * @return rewardToken The moe token
     */
    function _getRewardToken() internal view virtual override returns (IERC20 rewardToken) {
        return _moe;
    }

    /**
     * @dev Override the internal function to get the pending total rewards
     * Will call the MasterChef's getPendingRewards function to get the pending MOE rewards
     * @return pendingTotalRewards The pending total rewards
     */
    function _getPendingTotalRewards() internal view virtual override returns (uint256 pendingTotalRewards) {
        uint256[] memory pids = new uint256[](1);
        pids[0] = _getPid();

        (uint256[] memory moeRewards,,) = _masterChef.getPendingRewards(address(this), pids);
        uint256 remainingBalance = TokenHelper.safeBalanceOf(_getRewardToken(), address(this)) - _totalUnclaimedRewards;

        return moeRewards[0] + remainingBalance;
    }

    /**
     * @dev Override the internal function to update the rewards
     * Will call the MasterChef's deposit function to update the rewards
     * @return pendingTotalRewards The pending total rewards
     */
    function _updateRewards() internal virtual override returns (uint256 pendingTotalRewards) {
        _masterChef.deposit(_getPid(), 0);

        uint256 balance = TokenHelper.safeBalanceOf(_getRewardToken(), address(this));
        pendingTotalRewards = balance - _totalUnclaimedRewards;

        return pendingTotalRewards;
    }

    /**
     * @dev Override the internal function that is called when the hooks are set
     * Will set the symbol and name of this contract, while also minting 1 token
     * and depositing it on the MasterChef
     * @param data The data to be used on the hooks set
     */
    function _onHooksSet(bytes calldata data) internal virtual override {
        (, IERC20Metadata tokenX, IERC20Metadata tokenY, uint16 binStep) =
            abi.decode(data, (address, IERC20Metadata, IERC20Metadata, uint16));

        string memory symbolX = tokenX.symbol();
        string memory symbolY = tokenY.symbol();

        string memory symbol =
            string(abi.encodePacked("Vote LB ", symbolX, "-", symbolY, ":", Strings.toString(binStep)));
        string memory name = "LB Hooks Moe Rewarder";

        __ERC20_init(name, symbol);

        _mint(address(this), 1);
        _approve(address(this), address(_masterChef), 1);

        _masterChef.deposit(_getPid(), 1);
    }
}
