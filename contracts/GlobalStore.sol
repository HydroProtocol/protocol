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
pragma experimental ABIEncoderV2;

import "./lib/Store.sol";

/**
 * Global state store
 */
contract GlobalStore {
    Store.State state;

    modifier assetExist(
        address asset
    ) {
        require(address(state.oracles[asset]) != address(0), "ASSET_NOT_REGISTERED");
        _;
    }

    modifier assetNotExist(
        address asset
    ) {
        require(address(state.oracles[asset]) == address(0), "ASSET_ALREADY_REGISTERED");
        _;
    }

    modifier marketExist(
        uint16 marketId
    ) {
        require(marketId < state.marketsCount, "MARKET_NOT_REGISTERED");
        _;
    }

    modifier marketNotExist(
        uint16 marketId
    ) {
        require(marketId != state.marketsCount, "MARKET_ALREADY_REGISTERED");
        _;
    }
}