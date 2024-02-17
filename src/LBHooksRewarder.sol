// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable//token/ERC20/ERC20Upgradeable.sol";
import {IMasterChef, IMasterChefRewarder} from "@moe-core/src/interfaces/IMasterChef.sol";
import {ILBPair} from "@lb-protocol/src/interfaces/ILBPair.sol";
import {LBHooksBaseRewarder, Hooks} from "./LBHooksBaseRewarder.sol";
import {ILBHooksRewarder} from "./interfaces/ILBHooksRewarder.sol";
import {ILBHooksExtraRewarder} from "./interfaces/ILBHooksExtraRewarder.sol";

/**
 * @title LB Hooks Rewarder
 * @dev Main contract for the LB Hooks Rewarder
 * This contract will be used as a sink on the masterchef to receive MOE rewards and distribute them to the LPs
 * It can also have an extra rewarder to distribute a second token to the LPs
 * It will reward the LPs that are inside the range set in this contract
 */
contract LBHooksRewarder is LBHooksBaseRewarder, ERC20Upgradeable, ILBHooksRewarder {
    IMasterChef internal immutable _masterChef;
    IERC20 internal immutable _moe;

    bytes32 internal _extraHooksParameters;

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
    function setLBHooksExtraRewarder(ILBHooksExtraRewarder lbHooksExtraRewarder, bytes calldata extraRewarderData)
        external
        virtual
        override
    {
        if (msg.sender != _lbHooksManager) _checkOwner();

        if (address(lbHooksExtraRewarder) != address(0)) {
            bytes32 extraHooksParameters = Hooks.setHooks(FLAGS, address(lbHooksExtraRewarder));

            _extraHooksParameters = extraHooksParameters;

            if (lbHooksExtraRewarder.getLBPair() != _getLBPair() || lbHooksExtraRewarder.getParentRewarder() != this) {
                revert LBHooksRewarder__InvalidLBHooksExtraRewarder();
            }

            Hooks.onHooksSet(extraHooksParameters, extraRewarderData);
        } else {
            _extraHooksParameters = 0;
        }

        emit LBHooksExtraRewarderSet(lbHooksExtraRewarder);
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

        return moeRewards[0];
    }

    /**
     * @dev Override the internal function to update the rewards
     * Will call the MasterChef's deposit function to update the rewards
     * @return pendingTotalRewards The pending total rewards
     */
    function _updateRewards() internal virtual override returns (uint256 pendingTotalRewards) {
        _masterChef.deposit(_getPid(), 0);

        uint256 balance = _balanceOfThis(_getRewardToken());
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

    /**
     * @dev Override the internal function that is called when the rewards are claimed
     * Will call the extra rewarder's claim function if the extra rewarder is set
     * @param user The address of the user
     * @param ids The ids of the LP tokens
     */
    function _onClaim(address user, uint256[] calldata ids) internal virtual override {
        bytes32 extraHooksParameters = _extraHooksParameters;
        if (extraHooksParameters != 0) ILBHooksExtraRewarder(Hooks.getHooks(extraHooksParameters)).claim(user, ids);
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
     * @dev Override the internal function that is called after a mint on the LB pair
     * Will call the extra rewarder's afterMint function if the extra rewarder is set
     * @param from The address of the sender
     * @param to The address of the receiver
     * @param liquidityConfigs The liquidity configs
     * @param amountsIn The amounts in
     */
    function _afterMint(address from, address to, bytes32[] calldata liquidityConfigs, bytes32 amountsIn)
        internal
        virtual
        override
    {
        super._afterMint(from, to, liquidityConfigs, amountsIn);

        Hooks.afterMint(_extraHooksParameters, from, to, liquidityConfigs, amountsIn);
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
     * @dev Override the internal function that is called after a burn on the LB pair
     * Will call the extra rewarder's afterBurn function if the extra rewarder is set
     * @param sender The address of the sender
     * @param from The address of the sender
     * @param to The address of the receiver
     * @param ids The ids of the LP tokens
     * @param amountsToBurn The amounts to burn
     */
    function _afterBurn(
        address sender,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amountsToBurn
    ) internal virtual override {
        super._afterBurn(sender, from, to, ids, amountsToBurn);

        Hooks.afterBurn(_extraHooksParameters, sender, from, to, ids, amountsToBurn);
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

    /**
     * @dev Override the internal function that is called after a transfer on the LB pair
     * Will call the extra rewarder's afterBatchTransferFrom function if the extra rewarder is set
     * @param sender The address of the sender
     * @param from The address of the sender
     * @param to The address of the receiver
     * @param ids The list of ids
     * @param amounts The list of amounts
     */
    function _afterBatchTransferFrom(
        address sender,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) internal virtual override {
        super._afterBatchTransferFrom(sender, from, to, ids, amounts);

        Hooks.afterBatchTransferFrom(_extraHooksParameters, sender, from, to, ids, amounts);
    }
}
