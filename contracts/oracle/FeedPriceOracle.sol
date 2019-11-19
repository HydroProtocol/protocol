/*

    Copyright 2019 The Hydro Protocol Foundation

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity ^0.5.8;
pragma experimental ABIEncoderV2;

import "../lib/Ownable.sol";
import "../lib/SafeMath.sol";
import "../lib/Decimal.sol";

contract FeedPriceOracle is Ownable {
    using SafeMath for uint256;

    address[] public assets;
    uint256 public price;
    uint256 public lastBlockNumber;
    uint256 public validBlockNumber;
    uint256 public maxChangeRate;
    uint256 public minPrice;
    uint256 public maxPrice;

    event PriceFeed(
        uint256 price,
        uint256 blockNumber
    );

    constructor (
        address[] memory _assets,
        uint256 _validBlockNumber,
        uint256 _maxChangeRate,
        uint256 _minPrice,
        uint256 _maxPrice
    )
        public
    {
        assets = _assets;

        setParams(
            _validBlockNumber,
            _maxChangeRate,
            _minPrice,
            _maxPrice
        );
    }

    function setParams(
        uint256 _validBlockNumber,
        uint256 _maxChangeRate,
        uint256 _minPrice,
        uint256 _maxPrice
    )
        public
        onlyOwner
    {
        require(_minPrice <= _maxPrice, "MIN_PRICE_MUST_LESS_OR_EQUAL_THAN_MAX_PRICE");
        validBlockNumber = _validBlockNumber;
        maxChangeRate = _maxChangeRate;
        minPrice = _minPrice;
        maxPrice = _maxPrice;
    }

    function feed(
        uint256 newPrice
    )
        external
        onlyOwner
    {
        require(newPrice > 0, "PRICE_MUST_GREATER_THAN_0");
        require(lastBlockNumber < block.number, "BLOCKNUMBER_WRONG");
        require(newPrice <= maxPrice, "PRICE_EXCEED_MAX_LIMIT");
        require(newPrice >= minPrice, "PRICE_EXCEED_MIN_LIMIT");

        if (price > 0) {
            uint256 changeRate = Decimal.divFloor(newPrice, price);
            if (changeRate > Decimal.one()) {
                changeRate = changeRate.sub(Decimal.one());
            } else {
                changeRate = Decimal.one().sub(changeRate);
            }
            require(changeRate <= maxChangeRate, "PRICE_CHANGE_RATE_EXCEED");
        }

        price = newPrice;
        lastBlockNumber = block.number;

        emit PriceFeed(price, lastBlockNumber);
    }

    function isValidAsset(
        address asset
    )
        private
        view
        returns (bool)
    {
        for (uint256 i = 0; i < assets.length; i++ ) {
            if (assets[i] == asset) {
                return true;
            }
        }
        return false;
    }

    function getPrice(
        address _asset
    )
        external
        view
        returns (uint256)
    {
        require(isValidAsset(_asset), "ASSET_NOT_MATCH");
        require(block.number.sub(lastBlockNumber) <= validBlockNumber, "PRICE_EXPIRED");
        return price;
    }

}