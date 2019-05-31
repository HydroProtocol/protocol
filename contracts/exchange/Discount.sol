/*

    Copyright 2018 The Hydro Protocol Foundation

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

import "../lib/SafeMath.sol";
import "../lib/Consts.sol";
import "../lib/Store.sol";
import "../lib/Events.sol";

/**
 * Library to handle fee discount calculation
 */
library Discount {
    using SafeMath for uint256;

    /**
     * Get the HOT token balance of an address.
     *
     * @param owner The address to check.
     * @return The HOT balance for the owner address.
     */
    function getHotBalance(
        Store.State storage state,
        address owner
    )
        internal
        view
        returns (uint256 result)
    {
        address hotToken = state.hotTokenAddress;

        // EIP20Interface(hotTokenAddress).balanceOf(owner)

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
            // Keep these so we can restore stack memory upon completion
            let tmp1 := mload(0)
            let tmp2 := mload(4)

            // keccak256('balanceOf(address)') bitmasked to 4 bytes
            mstore(0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(4, owner)

            // No need to check the return value because hotToken is a trustworthy contract
            result := staticcall(
                gas,      // Forward all gas
                hotToken, // HOT token deployment address
                0,        // Pointer to start of calldata
                36,       // Length of calldata
                0,        // Overwrite calldata with output
                32        // Expecting uint256 output, the token balance
            )
            result := mload(0)

            // Restore stack memory
            mstore(0, tmp1)
            mstore(4, tmp2)
        }
    }

    function getDiscountedRate(
        Store.State storage state,
        address user
    )
        internal
        view
        returns (uint256 result)
    {
        uint256 hotBalance = getHotBalance(state, user);

        if (hotBalance == 0) {
            return Consts.DISCOUNT_RATE_BASE();
        }

        bytes32 config = state.exchange.discountConfig;
        uint256 count = uint256(uint8(byte(config)));
        uint256 bar;

        // HOT Token has 18 decimals
        hotBalance = hotBalance.div(10**18);

        for (uint256 i = 0; i < count; i++) {
            bar = uint256(uint32(bytes4(config << (2 + i * 5) * 8)));

            if (hotBalance < bar) {
                result = uint256(uint8(byte(config << (2 + i * 5 + 4) * 8)));
                break;
            }
        }

        // If we haven't found a rate in the config yet, use the maximum rate.
        if (result == 0) {
            result = uint256(uint8(config[1]));
        }

        // Make sure our discount algorithm never returns a higher rate than the base.
        require(result <= Consts.DISCOUNT_RATE_BASE(), "DISCOUNT_ERROR");
    }

    /**
     * @param newConfig A data blob representing the new discount config. Details on format above.
     */
    function changeDiscountConfig(
        Store.State storage state,
        bytes32 newConfig
    )
        internal
    {
        state.exchange.discountConfig = newConfig;
        Events.logDiscountConfigChange(newConfig);
    }
}