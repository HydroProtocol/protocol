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

import "./Store.sol";

library ExternalCaller {
    function getAssetPriceFromPriceOracle(
        Store.State storage state,
        address asset
    )
        internal
        view
        returns (uint256 result)
    {
        // After test, the assembly way saves about 5000 gas.
        // equal to :
        //   return state.assets[asset].priceOracle.getPrice(asset);

        address oracleAddress = address(state.assets[asset].priceOracle);

        assembly {
            let freePtr := mload(0x40)

            // keccak256('getPrice(address)') & 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
            mstore(freePtr, 0x41976e0900000000000000000000000000000000000000000000000000000000)
            mstore(add(freePtr, 4), asset)

            // call ERC20 Token contract transfer function
            let callResult := staticcall(gas, oracleAddress, freePtr, 36, freePtr, 32)
            result := mload(0)

            mstore(freePtr, 0)
            mstore(add(freePtr, 4), 0)
        }
    }
}