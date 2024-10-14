// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ILBPair} from "@lb-protocol/src/interfaces/ILBPair.sol";
import {Hooks, ILBHooks} from "@lb-protocol/src/libraries/Hooks.sol";
import {IMasterChef} from "@moe-core/src/interfaces/IMasterChef.sol";

import {ILBHooksManager} from "./interfaces/ILBHooksManager.sol";
import {ILBHooksBaseParentRewarder} from "./interfaces/ILBHooksBaseParentRewarder.sol";
import {ILBHooksMCRewarder} from "./interfaces/ILBHooksMCRewarder.sol";
import {ILBHooksBaseRewarder} from "./interfaces/ILBHooksBaseRewarder.sol";
import {ILBHooksExtraRewarder} from "./interfaces/ILBHooksExtraRewarder.sol";

contract LBHooksLens {
    struct HooksRewarderData {
        Hooks.Parameters hooksParameters;
        Parameters parameters;
        uint256 activeId;
    }

    struct Parameters {
        ILBHooksManager.LBHooksType hooksType;
        Token rewardToken;
        uint256 pid;
        uint256 moePerSecond;
        uint256 activeId;
        uint256 rangeStart;
        uint256 rangeEnd;
        uint256 pendingRewards;
        uint256 rewardPerSecond;
        uint256 lastUpdateTimestamp;
        uint256 endTimestamp;
        uint256 remainingRewards;
        bool isStarted;
        bool isEnded;
    }

    struct Token {
        address token;
        uint256 decimals;
        string symbol;
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
            bytes32 hooksParameters = ILBHooksBaseParentRewarder(rewarder).getExtraHooksParameters();

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

    function getRewardToken(address rewarder) public view returns (Token memory rewardToken) {
        if (msg.sender == address(this)) {
            address token = address(ILBHooksBaseParentRewarder(rewarder).getRewardToken());

            rewardToken.token = token;

            if (token != address(0)) {
                rewardToken.decimals = IERC20Metadata(token).decimals();
                rewardToken.symbol = IERC20Metadata(token).symbol();
            } else {
                rewardToken.decimals = 18;
                rewardToken.symbol = "MNT";
            }
        } else {
            try this.getRewardToken(rewarder) returns (Token memory r) {
                return r;
            } catch {
                return Token(address(0), 0, "");
            }
        }
    }

    function getPid(address rewarder) public view returns (uint256) {
        if (msg.sender == address(this)) {
            return ILBHooksMCRewarder(rewarder).getPid();
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
            return ILBHooksBaseParentRewarder(rewarder).getRewardedRange();
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

    function getParametersOf(address hooks, address user, uint256[] calldata ids)
        public
        view
        returns (Parameters memory parameters)
    {
        if (hooks != address(0)) {
            parameters.hooksType = getLBHooksType(hooks);
            parameters.rewardToken = getRewardToken(hooks);
            (parameters.rangeStart, parameters.rangeEnd) = getRewardedRange(hooks);

            if (uint8(parameters.hooksType) % 3 == 1) {
                parameters.pid = getPid(hooks);
                parameters.moePerSecond = getMoePerSecond(parameters.pid);
            } else {
                (parameters.rewardPerSecond, parameters.lastUpdateTimestamp, parameters.endTimestamp) =
                    getRewarderParameter(hooks);
                parameters.remainingRewards = getRemainingRewards(hooks);
                parameters.isStarted = block.timestamp >= parameters.lastUpdateTimestamp;
                parameters.isEnded = block.timestamp >= parameters.endTimestamp;
            }

            if (user != address(0)) parameters.pendingRewards = getPendingRewards(hooks, user, ids);
        }
    }

    function getHooksData(address pair, address user, uint256[] calldata ids)
        public
        view
        returns (HooksRewarderData memory rewarderData, HooksRewarderData memory extraRewarderData)
    {
        rewarderData.hooksParameters = getHooks(pair);
        rewarderData.parameters = getParametersOf(rewarderData.hooksParameters.hooks, user, ids);
        rewarderData.activeId = getActiveId(pair);

        extraRewarderData.hooksParameters = getExtraHooks(rewarderData.hooksParameters.hooks);
        extraRewarderData.parameters = getParametersOf(extraRewarderData.hooksParameters.hooks, user, ids);
        extraRewarderData.activeId = rewarderData.activeId;
    }

    function getBatchHooksData(address[] calldata pairs, address user, uint256[][] calldata ids)
        public
        view
        returns (HooksRewarderData[] memory rewarderData, HooksRewarderData[] memory extraRewarderData)
    {
        rewarderData = new HooksRewarderData[](pairs.length);
        extraRewarderData = new HooksRewarderData[](pairs.length);

        for (uint256 i = 0; i < pairs.length; i++) {
            (rewarderData[i], extraRewarderData[i]) = getHooksData(pairs[i], user, ids[i]);
        }
    }
}
