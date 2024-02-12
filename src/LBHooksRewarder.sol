// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {IMasterChef, IMasterChefRewarder} from "@moe-core/src/interfaces/IMasterChef.sol";
import {ILBPair} from "@lb-protocol/src/interfaces/ILBPair.sol";
import {LBHooksBaseRewarder} from "./LBHooksBaseRewarder.sol";
import {ILBHooksRewarder} from "./interfaces/ILBHooksRewarder.sol";

contract LBHooksRewarder is LBHooksBaseRewarder, ERC20Upgradeable, ILBHooksRewarder {
    IMasterChef internal immutable _masterChef;

    constructor(address masterChef) {
        _masterChef = IMasterChef(masterChef);
    }

    function getPid() external view virtual returns (uint256 pid) {
        return _getPid();
    }

    function getMasterChef() external view virtual returns (IMasterChef masterChef) {
        return _masterChef;
    }

    function _getPid() internal pure virtual returns (uint256 pid) {
        return _getArgUint256(20);
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

    function _onHooksSet(bytes32 hooksParameters, bytes calldata data) internal virtual override {
        super._onHooksSet(hooksParameters, data);

        ILBPair lbPair = _getLBPair();

        IERC20Metadata tokenX = IERC20Metadata(address(lbPair.getTokenX()));
        IERC20Metadata tokenY = IERC20Metadata(address(lbPair.getTokenY()));

        string memory symbolX = tokenX.symbol();
        string memory symbolY = tokenY.symbol();

        string memory symbol =
            string(abi.encodePacked("Vote LB ", symbolX, "-", symbolY, ":", Strings.toString(lbPair.getBinStep())));
        string memory name = "LB Hooks Moe Rewarder";

        __ERC20_init(name, symbol);

        _masterChef.add(IERC20(this), IMasterChefRewarder(address(0)));

        _mint(address(this), 1);
        _approve(address(this), address(_masterChef), 1);

        _masterChef.deposit(_getPid(), 1);
    }
}
