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

pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./LibOwnable.sol";

/**
 * Library to handle fee discount calculation
 */
contract LibDiscount is LibOwnable {
    using SafeMath for uint256;
    
    // The base discounted rate is 100% of the current rate, or no discount.
    uint256 public constant DISCOUNT_RATE_BASE = 100;

    address public hotTokenAddress;

    constructor(address _hotTokenAddress) internal {
        hotTokenAddress = _hotTokenAddress;
    }

    /**
     * Get the HOT token balance of an address.
     *
     * @param owner The address to check.
     * @return The HOT balance for the owner address.
     */
    function getHotBalance(address owner) internal view returns (uint256 result) {
        address hotToken = hotTokenAddress;

        // IERC20(hotTokenAddress).balanceOf(owner)

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
            result := call(
                gas,      // Forward all gas
                hotToken, // HOT token deployment address
                0,        // Don't send any ETH
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

    bytes32 public discountConfig = 0x043c000027106400004e205a000075305000009c404600000000000000000000;

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
     * @param user The user address to calculate a fee discount for.
     * @return The percentage of the regular fee this user will pay.
     */
    function getDiscountedRate(address user) public view returns (uint256 result) {
        uint256 hotBalance = getHotBalance(user);

        if (hotBalance == 0) {
            return DISCOUNT_RATE_BASE;
        }

        bytes32 config = discountConfig;
        uint256 count = uint256(byte(config));
        uint256 bar;

        // HOT Token has 18 decimals
        hotBalance = hotBalance.div(10**18);

        for (uint256 i = 0; i < count; i++) {
            bar = uint256(bytes4(config << (2 + i * 5) * 8));

            if (hotBalance < bar) {
                result = uint256(byte(config << (2 + i * 5 + 4) * 8));
                break;
            }
        }

        // If we haven't found a rate in the config yet, use the maximum rate.
        if (result == 0) {
            result = uint256(config[1]);
        }

        // Make sure our discount algorithm never returns a higher rate than the base.
        require(result <= DISCOUNT_RATE_BASE, "DISCOUNT_ERROR");
    }

    /**
     * Owner can modify discount configuration.
     *
     * @param newConfig A data blob representing the new discount config. Details on format above.
     */
    function changeDiscountConfig(bytes32 newConfig) external onlyOwner {
        discountConfig = newConfig;
    }
}