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

import "../lib/SafeMath.sol";
import "../lib/Consts.sol";
import "../lib/Store.sol";
import "../lib/AssemblyCall.sol";

/**
 * Library to handle fee discount calculation
 */
library Discount {
    using SafeMath for uint256;

    /**
     * Calculate and return the rate at which fees will be charged for an address. The discounted
     * rate depends on how much HOT token is owned by the user. Values returned will be a percentage
     * used to calculate how much of the fee is paid, so a return value of 100 means there is 0
     * discount, and a return value of 70 means a 30% rate reduction.
     *
     * The discountConfig is defined as such:
     * ╔═══════════════════╤════════════════════════════════════════════╗
     * ║                   │ length(bytes)   desc                       ║
     * ╟───────────────────┼────────────────────────────────────────────╢
     * ║ count             │ 1               the count of configs       ║
     * ║ maxDiscountedRate │ 1               the max discounted rate    ║
     * ║ config            │ 5 each                                     ║
     * ╚═══════════════════╧════════════════════════════════════════════╝
     *
     * The default discount structure as defined in code would give the following result:
     *
     * Fee discount table
     * ╔════════════════════╤══════════╗
     * ║     HOT BALANCE    │ DISCOUNT ║
     * ╠════════════════════╪══════════╣
     * ║     0 <= x < 10000 │     0%   ║
     * ╟────────────────────┼──────────╢
     * ║ 10000 <= x < 20000 │    10%   ║
     * ╟────────────────────┼──────────╢
     * ║ 20000 <= x < 30000 │    20%   ║
     * ╟────────────────────┼──────────╢
     * ║ 30000 <= x < 40000 │    30%   ║
     * ╟────────────────────┼──────────╢
     * ║ 40000 <= x         │    40%   ║
     * ╚════════════════════╧══════════╝
     *
     * Breaking down the bytes of 0x043c000027106400004e205a000075305000009c404600000000000000000000
     *
     * 0x  04           3c          0000271064  00004e205a  0000753050  00009c4046  0000000000  0000000000;
     *     ~~           ~~          ~~~~~~~~~~  ~~~~~~~~~~  ~~~~~~~~~~  ~~~~~~~~~~  ~~~~~~~~~~  ~~~~~~~~~~
     *      |            |               |           |           |           |           |           |
     *    count  maxDiscountedRate       1           2           3           4           5           6
     *
     * The first config breaks down as follows:  00002710   64
     *                                           ~~~~~~~~   ~~
     *                                               |      |
     *                                              bar    rate
     *
     * Meaning if a user has less than 10000 (0x00002710) HOT, they will pay 100%(0x64) of the
     * standard fee.
     *
     * @param  user The user address to calculate a fee discount for.
     * @return      The percentage of the regular fee this user will pay.
     */
    function getDiscountedRate(
        Store.State storage state,
        address user
    )
        internal
        view
        returns (uint256 result)
    {
        uint256 hotBalance = AssemblyCall.getHotBalance(
            state.exchange.hotTokenAddress,
            user
        );

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
}