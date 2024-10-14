// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILBHooks} from "@lb-protocol/src/interfaces/ILBHooks.sol";

/**
 * @title LB Hooks Manager Interface
 * @dev Interface for the LB Hooks Manager
 */
interface ILBHooksManager {
    error LBHooksManager__InvalidLBHooksType();
    error LBHooksManager__LBHooksParametersNotSet();
    error LBHooksManager__LBPairNotFound();
    error LBHooksManager__LBHooksNotSetOnPair();
    error LBHooksManager__UnorderedTokens();

    enum LBHooksType {
        Invalid,
        DeltaMCRewarder,
        DeltaExtraRewarder,
        DeltaSimpleRewarder,
        StaticMCRewarder,
        StaticExtraRewarder,
        StaticSimpleRewarder,
        OracleMCRewarder,
        OracleExtraRewarder,
        OracleSimpleRewarder
    }

    event HooksParametersSet(LBHooksType lbHooksType, bytes32 hooksParameters);

    event HooksCreated(LBHooksType lbHooksType, uint256 id, ILBHooks hooks);

    function getLBHooksParameters(LBHooksType lbHooksType) external view returns (bytes32 hooksParameters);

    function getHooksAt(LBHooksType lbHooksType, uint256 index) external view returns (ILBHooks hooks);

    function getHooksLength(LBHooksType lbHooksType) external view returns (uint256 length);

    function getLBHooksType(ILBHooks hooks) external view returns (LBHooksType lbHooksType);

    function setLBHooksParameters(LBHooksType lbHooksType, bytes32 hooksParameters) external;

    function createLBHooksMCRewarder(
        LBHooksType lbHooksType,
        IERC20 tokenX,
        IERC20 tokenY,
        uint16 binStep,
        address initialOwner
    ) external returns (address);

    function createLBHooksSimpleRewarder(
        LBHooksType lbHooksType,
        IERC20 tokenX,
        IERC20 tokenY,
        uint16 binStep,
        IERC20 rewardToken,
        address initialOwner
    ) external returns (address);

    function createLBHooksExtraRewarder(
        LBHooksType lbHooksType,
        IERC20 tokenX,
        IERC20 tokenY,
        uint16 binStep,
        IERC20 rewardToken,
        address initialOwner
    ) external returns (address);
}
