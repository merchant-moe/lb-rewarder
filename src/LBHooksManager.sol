// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ImmutableClone} from "@lb-protocol/src/libraries/ImmutableClone.sol";
import {Hooks, ILBHooks} from "@lb-protocol/src/libraries/Hooks.sol";
import {ILBFactory, IERC20 as LB_IERC20} from "@lb-protocol/src/interfaces/ILBFactory.sol";
import {ILBPair} from "@lb-protocol/src/interfaces/ILBPair.sol";
import {IMasterChef} from "@moe-core/src/interfaces/IMasterChef.sol";
import {IMasterChefRewarder} from "@moe-core/src/interfaces/IMasterChef.sol";
import {ILBHooksRewarder} from "./interfaces/ILBHooksRewarder.sol";
import {ILBHooksExtraRewarder} from "./interfaces/ILBHooksExtraRewarder.sol";
import {ILBHooksManager} from "./interfaces/ILBHooksManager.sol";

contract LBHooksManager is Ownable2StepUpgradeable, ILBHooksManager {
    ILBFactory internal immutable _lbFactory;
    IMasterChef internal immutable _masterChef;
    IERC20 internal immutable _moe;

    mapping(LBHooksType => bytes32) private _lbHooksParameters;

    mapping(LBHooksType => ILBHooks[]) private _hooks;
    mapping(ILBHooks => LBHooksType) private _lbHooksTypes;

    constructor(ILBFactory lbFactory, IMasterChef masterChef, IERC20 moe) {
        _lbFactory = lbFactory;
        _masterChef = masterChef;
        _moe = moe;

        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
    }

    function getLBHooksParameters(LBHooksType lbHooksType) external view returns (bytes32 hooksParameters) {
        return _lbHooksParameters[lbHooksType];
    }

    function getHooksAt(LBHooksType lbHooksType, uint256 index) external view returns (ILBHooks hooks) {
        return _hooks[lbHooksType][index];
    }

    function getHooksLength(LBHooksType lbHooksType) external view returns (uint256 length) {
        return _hooks[lbHooksType].length;
    }

    function getLBHooksType(ILBHooks hooks) external view returns (LBHooksType lbHooksType) {
        return _lbHooksTypes[hooks];
    }

    function setLBHooksParameters(LBHooksType lbHooksType, bytes32 hooksParameters) external onlyOwner {
        if (lbHooksType == LBHooksType.Invalid) revert LBHooksManager__InvalidLBHooksType();

        _lbHooksParameters[lbHooksType] = hooksParameters;

        emit HooksParametersSet(lbHooksType, hooksParameters);
    }

    function createLBHooksRewarder(IERC20 tokenX, IERC20 tokenY, uint16 binStep, address initialOwner)
        external
        onlyOwner
        returns (ILBHooksRewarder rewarder)
    {
        (ILBPair lbPair, bytes32 hooksParameters) =
            _getLBPairAndHooksParameters(LBHooksType.Rewarder, tokenX, tokenY, binStep);

        uint256 pid = _masterChef.getNumberOfFarms();
        bytes memory immutableData = abi.encodePacked(lbPair, pid);

        rewarder = ILBHooksRewarder(_cloneHooks(LBHooksType.Rewarder, Hooks.getHooks(hooksParameters), immutableData));

        _masterChef.add(IERC20(address(rewarder)), IMasterChefRewarder(address(0)));

        _lbFactory.setLBHooksParametersOnPair(
            LB_IERC20(address(tokenX)),
            LB_IERC20(address(tokenY)),
            binStep,
            Hooks.setHooks(hooksParameters, address(rewarder)),
            abi.encode(initialOwner, tokenX, tokenY, binStep)
        );
    }

    function createLBHooksExtraRewarder(
        IERC20 tokenX,
        IERC20 tokenY,
        uint16 binStep,
        IERC20 rewardToken,
        address initialOwner
    ) external onlyOwner returns (ILBHooksExtraRewarder extraRewarder) {
        (ILBPair lbPair, bytes32 hooksParameters) =
            _getLBPairAndHooksParameters(LBHooksType.ExtraRewarder, tokenX, tokenY, binStep);

        address lbHooksAddress = Hooks.getHooks(lbPair.getLBHooksParameters());

        if (lbHooksAddress == address(0)) revert LBHooksManager__LBHooksNotSetOnPair();

        bytes memory immutableData = abi.encodePacked(lbPair, rewardToken, lbHooksAddress);

        extraRewarder = ILBHooksExtraRewarder(
            _cloneHooks(LBHooksType.ExtraRewarder, Hooks.getHooks(hooksParameters), immutableData)
        );

        ILBHooksRewarder(lbHooksAddress).setLBHooksExtraRewarder(
            ILBHooksExtraRewarder(address(extraRewarder)), abi.encode(initialOwner)
        );
    }

    function _getLBPairAndHooksParameters(LBHooksType lbHooksType, IERC20 tokenX, IERC20 tokenY, uint16 binStep)
        internal
        view
        returns (ILBPair lbPair, bytes32 hooksParameters)
    {
        lbPair = _lbFactory.getLBPairInformation(LB_IERC20(address(tokenX)), LB_IERC20(address(tokenY)), binStep).LBPair;

        if (address(lbPair) == address(0)) revert LBHooksManager__LBPairNotFound();

        hooksParameters = _lbHooksParameters[lbHooksType];

        if (hooksParameters == bytes32(0)) revert LBHooksManager__LBHooksParametersNotSet();
    }

    function _cloneHooks(LBHooksType lbHooksType, address implementation, bytes memory immutableData)
        internal
        returns (address)
    {
        uint256 id = _hooks[lbHooksType].length;

        ILBHooks hooks = ILBHooks(
            ImmutableClone.cloneDeterministic(
                implementation, immutableData, bytes32(uint256(uint8(lbHooksType)) << 248 | id)
            )
        );

        _hooks[lbHooksType].push(hooks);
        _lbHooksTypes[hooks] = lbHooksType;

        emit HooksCreated(lbHooksType, id, hooks);

        return address(hooks);
    }
}
