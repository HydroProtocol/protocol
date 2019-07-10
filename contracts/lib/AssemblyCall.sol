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

/**
 * A collection of others contract function calls.
 * Use assembly to save gas.
 */
library AssemblyCall {
    function getAssetPriceFromPriceOracle(
        address oracleAddress,
        address asset
    )
        internal
        view
        returns (uint256)
    {
        // saves about 1200 gas.
        // return state.assets[asset].priceOracle.getPrice(asset);

        // keccak256('getPrice(address)') & 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
        bytes32 functionSelector = 0x41976e0900000000000000000000000000000000000000000000000000000000;

        (uint256 result, bool success) = callWith32BytesReturnsUint256(
            oracleAddress,
            functionSelector,
            bytes32(uint256(uint160(asset)))
        );

        if (!success) {
            revert("ASSEMBLY_CALL_GET_ASSET_PRICE_FAILED");
        }

        return result;
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
        returns (uint256)
    {
        // saves about 1200 gas.
        // return HydroToken(hotToken).balanceOf(owner);

        // keccak256('balanceOf(address)') bitmasked to 4 bytes
        bytes32 functionSelector = 0x70a0823100000000000000000000000000000000000000000000000000000000;

        (uint256 result, bool success) = callWith32BytesReturnsUint256(
            hotToken,
            functionSelector,
            bytes32(uint256(uint160(owner)))
        );

        if (!success) {
            revert("ASSEMBLY_CALL_GET_HOT_BALANCE_FAILED");
        }

        return result;
    }

    function getBorrowInterestRate(
        address interestModel,
        uint256 borrowRatio
    )
        internal
        view
        returns (uint256)
    {
        // saves about 1200 gas.
        // return IInterestModel(interestModel).polynomialInterestModel(borrowRatio);

        // keccak256('polynomialInterestModel(uint256)') & 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
        bytes32 functionSelector = 0x69e8a15f00000000000000000000000000000000000000000000000000000000;

        (uint256 result, bool success) = callWith32BytesReturnsUint256(
            interestModel,
            functionSelector,
            bytes32(borrowRatio)
        );

        if (!success) {
            revert("ASSEMBLY_CALL_GET_BORROW_INTEREST_RATE_FAILED");
        }

        return result;
    }

    function callWith32BytesReturnsUint256(
        address to,
        bytes32 functionSelector,
        bytes32 param1
    )
        private
        view
        returns (uint256 result, bool success)
    {
        assembly {
            let freePtr := mload(0x40)
            let tmp1 := mload(freePtr)
            let tmp2 := mload(add(freePtr, 4))

            mstore(freePtr, functionSelector)
            mstore(add(freePtr, 4), param1)

            // call ERC20 Token contract transfer function
            success := staticcall(
                gas,           // Forward all gas
                to,            // Interest Model Address
                freePtr,       // Pointer to start of calldata
                36,            // Length of calldata
                freePtr,       // Overwrite calldata with output
                32             // Expecting uint256 output
            )

            result := mload(freePtr)

            mstore(freePtr, tmp1)
            mstore(add(freePtr, 4), tmp2)
        }
    }
}