// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ImmutableClone} from "@lb-protocol/src/libraries/ImmutableClone.sol";
import {Hooks, ILBHooks} from "@lb-protocol/src/libraries/Hooks.sol";
import {ILBFactory} from "@lb-protocol/src/interfaces/ILBFactory.sol";
import {ILBPair} from "@lb-protocol/src/interfaces/ILBPair.sol";
import {IMasterChef} from "@moe-core/src/interfaces/IMasterChef.sol";
import {IMasterChefRewarder} from "@moe-core/src/interfaces/IMasterChef.sol";
import {ILBHooksMCRewarder} from "./interfaces/ILBHooksMCRewarder.sol";
import {ILBHooksExtraRewarder} from "./interfaces/ILBHooksExtraRewarder.sol";
import {ILBHooksManager} from "./interfaces/ILBHooksManager.sol";

/**
 * @title LB Hooks Manager
 * @dev This contract is used to create and set LB Hooks.
 * Currently, it is used to manage the creation of LB Hooks Rewarder and LB Hooks Extra Rewarder.
 */
contract LBHooksManager is Ownable2StepUpgradeable, ILBHooksManager {
    ILBFactory internal immutable _lbFactory;
    IMasterChef internal immutable _masterChef;

    mapping(LBHooksType => bytes32) private _lbHooksParameters;

    mapping(LBHooksType => ILBHooks[]) private _hooks;
    mapping(ILBHooks => LBHooksType) private _lbHooksTypes;

    /**
     * @dev Constructor of the contract
     * @param lbFactory The address of the LBFactory contract
     * @param masterChef The address of the MasterChef contract
     */
    constructor(ILBFactory lbFactory, IMasterChef masterChef) {
        _lbFactory = lbFactory;
        _masterChef = masterChef;

        _disableInitializers();
    }

    /**
     * @dev Initializes the contract
     * @param initialOwner The address of the initial owner
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
    }

    /**
     * @dev Returns the LB Hooks parameters for the given LB Hooks type
     * @param lbHooksType The LB Hooks type
     * @return hooksParameters The LB Hooks parameters
     */
    function getLBHooksParameters(LBHooksType lbHooksType) external view override returns (bytes32 hooksParameters) {
        return _lbHooksParameters[lbHooksType];
    }

    /**
     * @dev Returns the LB Hooks at the given index for the given LB Hooks type
     * @param lbHooksType The LB Hooks type
     * @param index The index of the LB Hooks
     * @return hooks The LB Hooks
     */
    function getHooksAt(LBHooksType lbHooksType, uint256 index) external view override returns (ILBHooks hooks) {
        return _hooks[lbHooksType][index];
    }

    /**
     * @dev Returns the length of the LB Hooks for the given LB Hooks type
     * @param lbHooksType The LB Hooks type
     * @return length The length of the LB Hooks
     */
    function getHooksLength(LBHooksType lbHooksType) external view override returns (uint256 length) {
        return _hooks[lbHooksType].length;
    }

    /**
     * @dev Returns the LB Hooks type for the given LB Hooks
     * @param hooks The LB Hooks
     * @return lbHooksType The LB Hooks type
     */
    function getLBHooksType(ILBHooks hooks) external view override returns (LBHooksType lbHooksType) {
        return _lbHooksTypes[hooks];
    }

    /**
     * @dev Sets the LB Hooks parameters for the given LB Hooks type
     * Only callable by the owner
     * @param lbHooksType The LB Hooks type
     * @param hooksParameters The LB Hooks parameters
     */
    function setLBHooksParameters(LBHooksType lbHooksType, bytes32 hooksParameters) external override onlyOwner {
        if (lbHooksType == LBHooksType.Invalid) revert LBHooksManager__InvalidLBHooksType();

        _lbHooksParameters[lbHooksType] = hooksParameters;

        emit HooksParametersSet(lbHooksType, hooksParameters);
    }

    /**
     * @dev Creates a new LB Hooks Rewarder
     * This will also try to set the LB Hooks parameters on the pair
     * Only callable by the owner
     * @param tokenX The address of the token X
     * @param tokenY The address of the token Y
     * @param binStep The bin step
     * @param initialOwner The address of the initial owner
     * @return rewarder The address of the LB Hooks Rewarder
     */
    function createLBHooksRewarder(IERC20 tokenX, IERC20 tokenY, uint16 binStep, address initialOwner)
        external
        override
        onlyOwner
        returns (ILBHooksMCRewarder rewarder)
    {
        (ILBPair lbPair, bytes32 hooksParameters) =
            _getLBPairAndHooksParameters(LBHooksType.MCRewarder, tokenX, tokenY, binStep);

        uint256 pid = _masterChef.getNumberOfFarms();
        bytes memory immutableData = abi.encodePacked(lbPair, pid);

        rewarder =
            ILBHooksMCRewarder(_cloneHooks(LBHooksType.MCRewarder, Hooks.getHooks(hooksParameters), immutableData));

        _masterChef.add(IERC20(address(rewarder)), IMasterChefRewarder(address(0)));

        _lbFactory.setLBHooksParametersOnPair(
            tokenX,
            tokenY,
            binStep,
            Hooks.setHooks(hooksParameters, address(rewarder)),
            abi.encode(initialOwner, tokenX, tokenY, binStep)
        );
    }

    /**
     * @dev Creates a new LB Hooks Extra Rewarder
     * This will also try to set the LB Hooks Extra Rewarder on the Rewarder of the pair
     * Only callable by the owner
     * @param tokenX The address of the token X
     * @param tokenY The address of the token Y
     * @param binStep The bin step
     * @param rewardToken The address of the reward token
     * @param initialOwner The address of the initial owner
     * @return extraRewarder The address of the LB Hooks Extra Rewarder
     */
    function createLBHooksExtraRewarder(
        IERC20 tokenX,
        IERC20 tokenY,
        uint16 binStep,
        IERC20 rewardToken,
        address initialOwner
    ) external override onlyOwner returns (ILBHooksExtraRewarder extraRewarder) {
        (ILBPair lbPair, bytes32 hooksParameters) =
            _getLBPairAndHooksParameters(LBHooksType.ExtraRewarder, tokenX, tokenY, binStep);

        address lbHooksAddress = Hooks.getHooks(lbPair.getLBHooksParameters());

        if (lbHooksAddress == address(0)) revert LBHooksManager__LBHooksNotSetOnPair();

        bytes memory immutableData = abi.encodePacked(lbPair, rewardToken, lbHooksAddress);

        extraRewarder = ILBHooksExtraRewarder(
            _cloneHooks(LBHooksType.ExtraRewarder, Hooks.getHooks(hooksParameters), immutableData)
        );

        ILBHooksMCRewarder(lbHooksAddress).setLBHooksExtraRewarder(
            ILBHooksExtraRewarder(address(extraRewarder)), abi.encode(initialOwner)
        );
    }

    /**
     * @dev Internal function to get the LB Pair and the LB Hooks parameters for the given LB Hooks type
     * @param lbHooksType The LB Hooks type
     * @param tokenX The address of the token X
     * @param tokenY The address of the token Y
     * @param binStep The bin step
     * @return lbPair The LB Pair
     * @return hooksParameters The LB Hooks parameters
     */
    function _getLBPairAndHooksParameters(LBHooksType lbHooksType, IERC20 tokenX, IERC20 tokenY, uint16 binStep)
        internal
        view
        returns (ILBPair lbPair, bytes32 hooksParameters)
    {
        lbPair = _lbFactory.getLBPairInformation(tokenX, tokenY, binStep).LBPair;

        if (address(lbPair) == address(0)) revert LBHooksManager__LBPairNotFound();
        if (lbPair.getTokenX() != tokenX) revert LBHooksManager__UnorderedTokens();

        hooksParameters = _lbHooksParameters[lbHooksType];

        if (hooksParameters == bytes32(0)) revert LBHooksManager__LBHooksParametersNotSet();
    }

    /**
     * @dev Internal function to create a new rewarder using the given implementation and immutable data
     * @param lbHooksType The LB Hooks type
     * @param implementation The address of the implementation
     * @param immutableData The immutable data
     * @return hooks The address of the LB Hooks
     */
    function _cloneHooks(LBHooksType lbHooksType, address implementation, bytes memory immutableData)
        internal
        returns (address)
    {
        uint256 id = _hooks[lbHooksType].length;

        ILBHooks hooks = ILBHooks(
            ImmutableClone.cloneDeterministic(
                implementation, immutableData, bytes32((uint256(uint8(lbHooksType)) << 248) | id)
            )
        );

        _hooks[lbHooksType].push(hooks);
        _lbHooksTypes[hooks] = lbHooksType;

        emit HooksCreated(lbHooksType, id, hooks);

        return address(hooks);
    }
}
