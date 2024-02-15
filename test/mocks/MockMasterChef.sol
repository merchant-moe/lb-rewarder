// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@moe-core/src/interfaces/IMasterChef.sol";

import "./MockERC20.sol";

contract MockMasterChef {
    mapping(uint256 => mapping(address => uint256)) public balances;
    IERC20[] public tokens;

    IERC20 public immutable rewardToken;

    uint256 public lastUpdate;

    constructor(IERC20 _rewardToken) {
        rewardToken = _rewardToken;

        lastUpdate = block.timestamp;
    }

    function getNumberOfFarms() external view returns (uint256) {
        return tokens.length;
    }

    function add(IERC20 token, IMasterChefRewarder) external {
        tokens.push(token);
    }

    function deposit(uint256 pid, uint256 amount) external {
        balances[pid][msg.sender] += amount;

        if (amount > 0) tokens[pid].transferFrom(msg.sender, address(this), amount);

        _claimRewards();
    }

    function getPendingRewards(address, uint256[] memory ids)
        external
        view
        returns (uint256[] memory rewards, IERC20[] memory extraToken, uint256[] memory extraAmount)
    {
        rewards = new uint256[](ids.length);
        extraToken = new IERC20[](ids.length);
        extraAmount = new uint256[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            rewards[i] = (block.timestamp - lastUpdate) * 1e18;
        }
    }

    function _claimRewards() internal {
        uint256 lastUpdate_ = lastUpdate;
        lastUpdate = block.timestamp;

        uint256 rewards = (block.timestamp - lastUpdate_) * 1e18;

        if (rewards > 0) MockERC20(address(rewardToken)).mint(msg.sender, rewards);
    }
}
