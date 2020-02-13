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

import "../interfaces/IPriceOracle.sol";
import "../lib/SafeMath.sol";

contract PriceOracleProxy {
    using SafeMath for uint256;

    address public asset;
    uint256 public decimal;
    address public sourceOracleAddress;
    address public sourceAssetAddress;
    uint256 public sourceAssetDecimal;

    constructor (
        address _asset,
        uint256 _decimal,
        address _sourceOracleAddress,
        address _sourceAssetAddress,
        uint256 _sourceAssetDecimal
    )
        public
    {
        asset = _asset;
        decimal = _decimal;
        sourceOracleAddress = _sourceOracleAddress;
        sourceAssetAddress = _sourceAssetAddress;
        sourceAssetDecimal = _sourceAssetDecimal;
    }

    function _getPrice()
        internal
        view
        returns (uint256)
    {
        uint256 price = IPriceOracle(sourceOracleAddress).getPrice(sourceAssetAddress);

        if (decimal >= sourceAssetDecimal) {
            price = price.div(10 ** (decimal - sourceAssetDecimal));
        } else {
            price = price.mul(10 ** (sourceAssetDecimal - decimal));
        }

        return price;
    }

    function getPrice(
        address _asset
    )
        external
        view
        returns (uint256)
    {
        require(_asset == asset, "ASSET_NOT_MATCH");
        return _getPrice();
    }

    function getCurrentPrice()
        external
        view
        returns (uint256)
    {
        return _getPrice();
    }
}