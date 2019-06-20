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
        address oracleAddress,
        address asset
    )
        internal
        view
        returns (uint256 result)
    {
        // saves about 2500 gas.
        // equal to:
        //   return state.assets[asset].priceOracle.getPrice(asset);

        assembly {
            let freePtr := mload(0x40)

            // keccak256('getPrice(address)') & 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
            mstore(freePtr, 0x41976e0900000000000000000000000000000000000000000000000000000000)
            mstore(add(freePtr, 4), asset)

            // call ERC20 Token contract transfer function
            let callResult := staticcall(gas, oracleAddress, freePtr, 36, freePtr, 32)
            result := mload(freePtr)

            mstore(freePtr, 0)
            mstore(add(freePtr, 4), 0)
        }
    }

        /**
     * Get the HOT token balance of an address.
     *
     * @param owner The address to check.
     * @return The HOT balance for the owner address.
     */
    function getHotBalance(
        address hotToken,
        address owner
    )
        internal
        view
        returns (uint256 result)
    {
        // saves about 1200 gas.
        // equal to:
        //   return HydroToken(hotToken).balanceOf(owner);

        /**
         * We construct calldata for the `balanceOf` ABI.
         * The layout of this calldata is in the table below.
         *
         * ╔════════╤════════╤════════╤═══════════════════╗
         * ║ Area   │ Offset │ Length │ Contents          ║
         * ╟────────┼────────┼────────┼───────────────────╢
         * ║ Header │ 0      │ 4      │ function selector ║
         * ║ Params │ 4      │ 32     │ owner address     ║
         * ╚════════╧════════╧════════╧═══════════════════╝
         */
        assembly {
            let freePtr := mload(0x40)

            // keccak256('balanceOf(address)') bitmasked to 4 bytes
            mstore(freePtr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(freePtr, 4), owner)

            // No need to check the return value because hotToken is a trustworthy contract
            result := staticcall(
                gas,      // Forward all gas
                hotToken, // HOT token deployment address
                freePtr,        // Pointer to start of calldata
                36,       // Length of calldata
                freePtr,        // Overwrite calldata with output
                32        // Expecting uint256 output, the token balance
            )
            result := mload(freePtr)

            // Restore stack memory
            mstore(freePtr, 0)
            mstore(add(freePtr, 4), 0)
        }
    }
}