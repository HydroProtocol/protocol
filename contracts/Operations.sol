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

import "./GlobalStore.sol";
import "./lib/Ownable.sol";
import "./lib/Types.sol";
import "./funding/Markets.sol";
import "./exchange/Discount.sol";
import "./interfaces/OracleInterface.sol";

/**
 * Only owner can use this contract functions
 */
contract Operations is Ownable, GlobalStore {
    function addMarket(
        Types.Market calldata market
    )
        external
        onlyOwner
    {
        Markets.addMarket(state, market);
    }

    function registerOracle(
        address asset,
        address oracleAddress
    )
        external
        onlyOwner
    {
        state.oracles[asset] = OracleInterface(oracleAddress);
        // TODO event
    }

    /**
     * @param newConfig A data blob representing the new discount config. Details on format above.
     */
    function changeDiscountConfig(
        bytes32 newConfig
    )
        external
        onlyOwner
    {
        Discount.changeDiscountConfig(state, newConfig);
    }
}