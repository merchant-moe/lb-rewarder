// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {IMasterChef, IMasterChefRewarder} from "@moe-core/src/interfaces/IMasterChef.sol";
import {ILBPair} from "@lb-protocol/src/interfaces/ILBPair.sol";
import {LBHooksBaseRewarder, Hooks} from "./LBHooksBaseRewarder.sol";
import {ILBHooksRewarder} from "./interfaces/ILBHooksRewarder.sol";
import {ILBHooksExtraRewarder} from "./interfaces/ILBHooksExtraRewarder.sol";

contract LBHooksRewarder is LBHooksBaseRewarder, ERC20Upgradeable, ILBHooksRewarder {
    IMasterChef internal immutable _masterChef;
    IERC20 internal immutable _moe;

    bytes32 internal _extraHooksParameters;

    constructor(address lbHooksManager, IMasterChef masterChef, IERC20 moe) LBHooksBaseRewarder(lbHooksManager) {
        _masterChef = masterChef;
        _moe = moe;
    }

    function getPid() external view virtual returns (uint256 pid) {
        return _getPid();
    }

    function getMasterChef() external view virtual returns (IMasterChef masterChef) {
        return _masterChef;
    }

    function getExtraHooksParameters() external view virtual override returns (bytes32 extraHooksParameters) {
        return _extraHooksParameters;
    }

    function setLBHooksExtraRewarder(ILBHooksExtraRewarder lbHooksExtraRewarder, bytes calldata extraRewarderData)
        external
        virtual
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

    function _getPid() internal pure virtual returns (uint256 pid) {
        return _getArgUint256(20);
    }

    function _getRewardToken() internal view virtual override returns (IERC20 rewardToken) {
        return _moe;
    }

    function _getPendingTotalRewards() internal view virtual override returns (uint256 pendingTotalRewards) {
        uint256[] memory pids = new uint256[](1);
        pids[0] = _getPid();

        (uint256[] memory moeRewards,,) = _masterChef.getPendingRewards(address(this), pids);

        return moeRewards[0];
    }

    function _update() internal virtual override returns (uint256 pendingTotalRewards) {
        _masterChef.deposit(_getPid(), 0);

        uint256 balance = _balanceOfThis(_getRewardToken());
        pendingTotalRewards = balance - _totalUnclaimedRewards;

        return pendingTotalRewards;
    }

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

        bytes32 extraHooksParameters = _extraHooksParameters;
        if (extraHooksParameters != 0) Hooks.onHooksSet(extraHooksParameters, data);
    }

    function _onClaim(address user, uint256[] calldata ids) internal virtual override {
        bytes32 extraHooksParameters = _extraHooksParameters;
        if (extraHooksParameters != 0) ILBHooksExtraRewarder(Hooks.getHooks(extraHooksParameters)).claim(user, ids);
    }

    function _beforeSwap(address sender, address to, bool swapForY, bytes32 amountsIn) internal virtual override {
        super._beforeSwap(sender, to, swapForY, amountsIn);

        Hooks.beforeSwap(_extraHooksParameters, sender, to, swapForY, amountsIn);
    }

    function _beforeMint(address from, address to, bytes32[] calldata liquidityConfigs, bytes32 amountsReceived)
        internal
        virtual
        override
    {
        super._beforeMint(from, to, liquidityConfigs, amountsReceived);

        Hooks.beforeMint(_extraHooksParameters, from, to, liquidityConfigs, amountsReceived);
    }

    function _afterMint(address from, address to, bytes32[] calldata liquidityConfigs, bytes32 amountsIn)
        internal
        virtual
        override
    {
        super._afterMint(from, to, liquidityConfigs, amountsIn);

        Hooks.afterMint(_extraHooksParameters, from, to, liquidityConfigs, amountsIn);
    }

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
