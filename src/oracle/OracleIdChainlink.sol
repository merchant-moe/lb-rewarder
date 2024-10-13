// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PriceHelper} from "@lb-protocol/src/libraries/PriceHelper.sol";

import "../interfaces/IOracleId.sol";
import "../interfaces/IChainlinkAggregatorV3.sol";

/**
 * @title Oracle Id
 * @dev Contract that uses a chainlink price oracle to return the id of that price
 */
contract OracleIdChainlink is IOracleId {
    error OracleIdChainlink__InvalidPrice();
    error OracleIdChainlink__StalePrice();

    IChainlinkAggregatorV3 internal immutable _oracle;
    bool internal immutable _isInverse;
    uint256 internal immutable _oraclePrecision;
    uint256 internal immutable _heartbeat;

    uint16 internal immutable _binStep;

    /**
     * @dev Constructor of the contract
     * @param oracle The address of the chainlink aggregator
     * @param isInverse If the oracle is inversed, ie, if the actual price is the inverse of the oracle price
     * @param heartbeat The heartbeat of the oracle
     * @param binStep The bin step of the pair
     */
    constructor(IChainlinkAggregatorV3 oracle, bool isInverse, uint256 heartbeat, uint16 binStep) {
        _oracle = oracle;
        _isInverse = isInverse;
        _oraclePrecision = 10 ** oracle.decimals();
        _heartbeat = heartbeat;
        _binStep = binStep;
    }

    /**
     * @dev Returns the Oracle Id parameters
     * @return oracle The oracle address
     * @return isInverse If the oracle is inversed, ie, if the actual price is the inverse of the oracle price
     * @return oraclePrecision The oracle precision
     * @return heartbeat The heartbeat of the oracle
     * @return binStep The binStep of the pair
     */
    function getOracleIdParameters()
        external
        view
        returns (
            IChainlinkAggregatorV3 oracle,
            bool isInverse,
            uint256 oraclePrecision,
            uint256 heartbeat,
            uint256 binStep
        )
    {
        return (_oracle, _isInverse, _oraclePrecision, _heartbeat, _binStep);
    }

    /**
     * @dev Returns the latest id of the chainlink aggregator
     * @return The latest id
     */
    function getLatestId() external view override returns (uint24) {
        (, int256 answer,, uint256 updatedAt,) = _oracle.latestRoundData();

        if (answer <= 0 || uint256(answer) > type(uint128).max) revert OracleIdChainlink__InvalidPrice();
        if (block.timestamp > updatedAt + _heartbeat) revert OracleIdChainlink__StalePrice();

        uint256 priceX128 =
            _isInverse ? (_oraclePrecision << 128) / uint256(answer) : (uint256(answer) << 128) / _oraclePrecision;

        uint24 id = PriceHelper.getIdFromPrice(priceX128, _binStep);

        uint256 priceAtId = PriceHelper.getPriceFromId(id, _binStep);

        return priceAtId > priceX128 ? id - 1 : id;
    }
}
