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

import "../lib/Store.sol";
import "../lib/Types.sol";
import "../lib/Events.sol";
import "../interfaces/IOracle.sol";

library Markets {
    function getMarket(
        Store.State storage state,
        uint16 marketID
    )
        internal
        view
        returns (Types.Market memory)
    {
        return state.markets[marketID];
    }

    function getAllMarketsCount(
        Store.State storage state
    )
        internal
        view
        returns (uint256)
    {
        return state.marketsCount;
    }

    function addMarket(
        Store.State storage state,
        Types.Market memory market
    )
        internal
    {
        state.markets[state.marketsCount++] = market;
        Events.logMarketCreate(market);
    }
}