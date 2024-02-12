// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILBHooks} from "@lb-protocol/src/interfaces/ILBHooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILBHooksBaseRewarder is ILBHooks {
    error LBHooksBaseRewarder__InvalidDeltaBins();
    error LBHooksBaseRewarder__Overflow();
    error LBHooksBaseRewarder__NativeTransferFailed();
    error LBHooksBaseRewarder__UnlinkedHooks();
    error LBHooksBaseRewarder__InvalidHooksParameters();
    error LBHooksBaseRewarder__ZeroBalance();
    error LBHooksBaseRewarder__LockedRewardToken();
    error LBHooksBaseRewarder__NotNativeRewarder();
    error LBHooksBaseRewarder__InvalidExtraHooksRewarder();
    error LBHooksBaseRewarder__NoValueReceived();
    error LBHooksBaseRewarder__NotImplemented();

    event DeltaBinsSet(int24 deltaBinA, int24 deltaBinB);

    event ExtraHooksRewarderSet(address extraHooksRewarder);

    struct Bin {
        uint256 accRewardsPerShareX64;
        mapping(address => uint256) userAccRewardsPerShareX64;
    }

    function getRewardToken() external view returns (IERC20);

    function isStopped() external view returns (bool);

    function getPendingRewards(address user, uint256[] calldata ids) external view returns (uint256 pendingRewards);

    function claim(uint256[] calldata ids) external;

    function setDeltaBins(int24 deltaBinA, int24 deltaBinB) external;

    function setExtraHooksRewarder(address extraHooksRewarder, bytes calldata extraRewarderData) external;

    function sweep(IERC20 token, address to) external;
}
