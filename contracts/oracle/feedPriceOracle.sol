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

contract FeedPriceOracle is Ownable{
    using SafeMath for uint256;

    address public asset;
    uint256 public price;
    uint256 public lastBlockNumber;
    uint256 public validBlockNumber;
    uint256 public maxChangeRate;
    uint256 public minPrice;
    uint256 public maxPrice;

    uint256 constant ONE = 10**18;

    event PriceFeed(
        uint256 price,
        uint256 blockNumber
    );

    constructor (
        address _asset,
        uint256 _validBlockNumber,
        uint256 _maxChangeRate,
        uint256 _minPrice,
        uint256 _maxPrice
    )
        public
    {
        require(_minPrice <= _maxPrice, "MIN_PRICE_MUST_LESS_THAN_MAX_PRICE");
        asset = _asset;
        validBlockNumber = _validBlockNumber;
        maxChangeRate = _maxChangeRate;
        minPrice = _minPrice;
        maxPrice = _maxPrice;
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
        require(_minPrice <= _maxPrice, "MIN_PRICE_MUST_LESS_THAN_MAX_PRICE");
        validBlockNumber = _validBlockNumber;
        maxChangeRate = _maxChangeRate;
        minPrice = _minPrice;
        maxPrice = _maxPrice;
    }

    function feed(
        uint256 newPrice,
        uint256 blockNumber
    )
        public
        onlyOwner
    {
        require(newPrice > 0, "PRICE_MUST_GREATER_THAN_0");
        require(blockNumber <= block.number && blockNumber >= lastBlockNumber, "BLOCKNUMBER_WRONG");
        require(newPrice <= maxPrice, "PRICE_EXCEED_MAX_LIMIT");
        require(newPrice >= minPrice, "PRICE_EXCEED_MIN_LIMIT");

        if (price > 0){
            uint256 changeRate = newPrice.mul(ONE).div(price);
            if (changeRate > ONE){
                changeRate = changeRate.sub(ONE);
            } else {
                changeRate = ONE.sub(changeRate);
            }
            require(changeRate <= maxChangeRate, "PRICE_CHANGE_RATE_EXCEED");
        }

        price = newPrice;
        lastBlockNumber = blockNumber;
        emit PriceFeed(price, lastBlockNumber);
    }

    function getPrice(
        address _asset
    )
        public
        view
        returns (uint256)
    {
        require(asset == _asset, "ASSET_NOT_MATCH");
        require(block.number.sub(lastBlockNumber) <= validBlockNumber, "PRICE_EXPIRED");
        return price;
    }

}