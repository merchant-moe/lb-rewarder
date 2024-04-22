// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILBPair} from "@lb-protocol/src/interfaces/ILBPair.sol";
import {Hooks, ILBHooks} from "@lb-protocol/src/libraries/Hooks.sol";
import {IMasterChef} from "@moe-core/src/interfaces/IMasterChef.sol";

import {ILBHooksManager} from "./interfaces/ILBHooksManager.sol";
import {ILBHooksRewarder} from "./interfaces/ILBHooksRewarder.sol";
import {ILBHooksBaseRewarder} from "./interfaces/ILBHooksBaseRewarder.sol";
import {ILBHooksExtraRewarder} from "./interfaces/ILBHooksExtraRewarder.sol";

contract LBHooksLens {
    struct HooksRewarderData {
        Hooks.Parameters hooksParameters;
        ILBHooksManager.LBHooksType hooksType;
        address rewardToken;
        uint256 pid;
        uint256 moePerSecond;
        uint256 activeId;
        uint256 rangeStart;
        uint256 rangeEnd;
        uint256 pendingRewards;
    }

    struct ExtraHooksRewarderData {
        Hooks.Parameters hooksParameters;
        ILBHooksManager.LBHooksType hooksType;
        address rewardToken;
        uint256 rewardPerSecond;
        uint256 lastUpdateTimestamp;
        uint256 endTimestamp;
        uint256 remainingRewards;
        uint256 activeId;
        uint256 rangeStart;
        uint256 rangeEnd;
        uint256 pendingRewards;
        bool isStarted;
        bool isEnded;
    }

    ILBHooksManager internal immutable _lbHooksManager;
    IMasterChef internal immutable _masterChef;

    constructor(address lbHooksManager, address masterChef) {
        _lbHooksManager = ILBHooksManager(lbHooksManager);
        _masterChef = IMasterChef(masterChef);
    }

    function getHooks(address pair) public view returns (Hooks.Parameters memory) {
        if (msg.sender == address(this)) {
            bytes32 hooksParameters = ILBPair(pair).getLBHooksParameters();

            return Hooks.decode(hooksParameters);
        } else {
            try this.getHooks(pair) returns (Hooks.Parameters memory hooksParameters) {
                return hooksParameters;
            } catch {
                return
                    Hooks.Parameters(address(0), false, false, false, false, false, false, false, false, false, false);
            }
        }
    }

    function getExtraHooks(address rewarder) public view returns (Hooks.Parameters memory) {
        if (msg.sender == address(this)) {
            bytes32 hooksParameters = ILBHooksRewarder(rewarder).getExtraHooksParameters();

            return Hooks.decode(hooksParameters);
        } else {
            try this.getExtraHooks(rewarder) returns (Hooks.Parameters memory hooksParameters) {
                return hooksParameters;
            } catch {
                return
                    Hooks.Parameters(address(0), false, false, false, false, false, false, false, false, false, false);
            }
        }
    }

    function getRewardToken(address rewarder) public view returns (address) {
        if (msg.sender == address(this)) {
            return address(ILBHooksRewarder(rewarder).getRewardToken());
        } else {
            try this.getRewardToken(rewarder) returns (address rewardToken) {
                return rewardToken;
            } catch {
                return address(0);
            }
        }
    }

    function getPid(address rewarder) public view returns (uint256) {
        if (msg.sender == address(this)) {
            return ILBHooksRewarder(rewarder).getPid();
        } else {
            try this.getPid(rewarder) returns (uint256 pid) {
                return pid;
            } catch {
                return 0;
            }
        }
    }

    function getRewardedRange(address rewarder) public view returns (uint256, uint256) {
        if (msg.sender == address(this)) {
            return ILBHooksRewarder(rewarder).getRewardedRange();
        } else {
            try this.getRewardedRange(rewarder) returns (uint256 rangeStart, uint256 rangeEnd) {
                return (rangeStart, rangeEnd);
            } catch {
                return (0, 0);
            }
        }
    }

    function getActiveId(address pair) public view returns (uint256) {
        if (msg.sender == address(this)) {
            return ILBPair(pair).getActiveId();
        } else {
            try this.getActiveId(pair) returns (uint256 activeId) {
                return activeId;
            } catch {
                return 0;
            }
        }
    }

    function getPendingRewards(address rewarder, address account, uint256[] calldata ids)
        public
        view
        returns (uint256)
    {
        if (msg.sender == address(this)) {
            return ILBHooksBaseRewarder(rewarder).getPendingRewards(account, ids);
        } else {
            try this.getPendingRewards(rewarder, account, ids) returns (uint256 pendingReward) {
                return pendingReward;
            } catch {
                return 0;
            }
        }
    }

    function getLBHooksType(address rewarder) public view returns (ILBHooksManager.LBHooksType) {
        return _lbHooksManager.getLBHooksType(ILBHooks(rewarder));
    }

    function getMoePerSecond(uint256 pid) public view returns (uint256) {
        return _masterChef.getMoePerSecondForPid(pid);
    }

    function getRewarderParameter(address extraRewarder) public view returns (uint256, uint256, uint256) {
        if (msg.sender == address(this)) {
            return ILBHooksExtraRewarder(extraRewarder).getRewarderParameter();
        } else {
            try this.getRewarderParameter(extraRewarder) returns (
                uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp
            ) {
                return (rewardPerSecond, lastUpdateTimestamp, endTimestamp);
            } catch {
                return (0, 0, 0);
            }
        }
    }

    function getRemainingRewards(address extraRewarder) public view returns (uint256) {
        if (msg.sender == address(this)) {
            return ILBHooksExtraRewarder(extraRewarder).getRemainingRewards();
        } else {
            try this.getRemainingRewards(extraRewarder) returns (uint256 remainingRewards) {
                return remainingRewards;
            } catch {
                return 0;
            }
        }
    }

    function getHooksData(address pair, address user, uint256[] calldata ids)
        public
        view
        returns (HooksRewarderData memory rewarderData, ExtraHooksRewarderData memory extraRewarderData)
    {
        rewarderData.hooksParameters = getHooks(pair);

        address hooks = rewarderData.hooksParameters.hooks;

        if (hooks != address(0)) {
            rewarderData.hooksType = getLBHooksType(hooks);
            rewarderData.rewardToken = getRewardToken(hooks);
            rewarderData.pid = getPid(hooks);
            rewarderData.moePerSecond = getMoePerSecond(rewarderData.pid);
            rewarderData.activeId = getActiveId(pair);
            (rewarderData.rangeStart, rewarderData.rangeEnd) = getRewardedRange(hooks);

            if (user != address(0)) rewarderData.pendingRewards = getPendingRewards(hooks, user, ids);

            extraRewarderData.hooksParameters = getExtraHooks(hooks);

            address extraHooks = extraRewarderData.hooksParameters.hooks;

            if (extraHooks != address(0)) {
                extraRewarderData.hooksType = getLBHooksType(extraHooks);
                extraRewarderData.rewardToken = getRewardToken(extraHooks);
                (
                    extraRewarderData.rewardPerSecond,
                    extraRewarderData.lastUpdateTimestamp,
                    extraRewarderData.endTimestamp
                ) = getRewarderParameter(extraHooks);
                extraRewarderData.activeId = rewarderData.activeId;
                (extraRewarderData.rangeStart, extraRewarderData.rangeEnd) = getRewardedRange(extraHooks);
                extraRewarderData.remainingRewards = getRemainingRewards(extraHooks);
                extraRewarderData.isStarted = block.timestamp >= extraRewarderData.lastUpdateTimestamp;
                extraRewarderData.isEnded = block.timestamp >= extraRewarderData.endTimestamp;

                if (user != address(0)) extraRewarderData.pendingRewards = getPendingRewards(extraHooks, user, ids);
            }
        }
    }

    function getBatchHooksData(address[] calldata pairs, address user, uint256[][] calldata ids)
        public
        view
        returns (HooksRewarderData[] memory rewarderData, ExtraHooksRewarderData[] memory extraRewarderData)
    {
        rewarderData = new HooksRewarderData[](pairs.length);
        extraRewarderData = new ExtraHooksRewarderData[](pairs.length);

        for (uint256 i = 0; i < pairs.length; i++) {
            (rewarderData[i], extraRewarderData[i]) = getHooksData(pairs[i], user, ids[i]);
        }
    }
}
