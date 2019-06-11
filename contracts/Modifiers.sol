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

pragma solidity 0.5.8;

import "./GlobalStore.sol";

contract Modifiers is GlobalStore {
    modifier requireAssetExist(
        address asset
    ) {
        require(isAssetExist(asset), "ASSET_NOT_EXIST");
        _;
    }

    modifier requireAssetNotExist(
        address asset
    ) {
        require(!isAssetExist(asset), "ASSET_ALREADY_EXIST");
        _;
    }

    modifier requireMarketExist(
        Types.Market memory market
    ) {
        require(isMarketExist(market), "MARKET_NOT_EXIST");
        _;
    }

    modifier requireMarketIDAndAssetMatch(
        uint16 marketID,
        address asset
    ) {
        require(marketID < state.marketsCount, "MARKET_ID_NOT_EXIST");
        require(
            asset == state.markets[marketID].baseAsset || asset == state.markets[marketID].quoteAsset,
            "ASSET_NOT_BELONGS_TO_MARKET"
        );
        _;
    }

    modifier requireMarketNotExist(
        Types.Market memory market
    ) {
        require(!isMarketExist(market), "MARKET_ALREADY_EXIST");
        _;
    }

    modifier requireMarketAssetsValid(
        Types.Market memory market
    ) {
        require(market.baseAsset != market.quoteAsset, "BASE_QUOTE_DUPLICATED");
        require(isAssetExist(market.baseAsset), "MARKET_BASE_ASSET_NOT_EXIST");
        require(isAssetExist(market.quoteAsset), "MARKET_QUOTE_ASSET_NOT_EXIST");
        _;
    }

    function isAssetExist(
        address asset
    )
        internal
        view
        returns (bool)
    {
        return state.oracles[asset] != IOracle(address(0));
    }

    function isMarketExist(
        Types.Market memory market
    )
        internal
        view
        returns (bool)
    {
        for(uint16 i = 0; i < state.marketsCount; i++) {
            if (state.markets[i].baseAsset == market.baseAsset && state.markets[i].quoteAsset == market.quoteAsset) {
                return true;
            }
        }

        return false;
    }
}