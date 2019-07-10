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

/**
 * Math operations with safety checks that revert on error
 */
library SafeMath {

    // Multiplies two numbers, reverts on overflow.
    function mul(
        uint256 a,
        uint256 b
    )
        internal
        pure
        returns (uint256)
    {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "MUL_ERROR");

        return c;
    }

    // Integer division of two numbers truncating the quotient, reverts on division by zero.
    function div(
        uint256 a,
        uint256 b
    )
        internal
        pure
        returns (uint256)
    {
        require(b > 0, "DIVIDING_ERROR");
        return a / b;
    }

    function divCeil(
        uint256 a,
        uint256 b
    )
        internal
        pure
        returns (uint256)
    {
        uint256 quotient = div(a, b);
        uint256 remainder = a - quotient * b;
        if (remainder > 0) {
            return quotient + 1;
        } else {
            return quotient;
        }
    }

    // Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    function sub(
        uint256 a,
        uint256 b
    )
        internal
        pure
        returns (uint256)
    {
        require(b <= a, "SUB_ERROR");
        return a - b;
    }

    function sub(
        int256 a,
        uint256 b
    )
        internal
        pure
        returns (int256)
    {
        require(b <= 2**255-1, "INT256_SUB_ERROR");
        int256 c = a - int256(b);
        require(c <= a, "INT256_SUB_ERROR");
        return c;
    }

    // Adds two numbers, reverts on overflow.
    function add(
        uint256 a,
        uint256 b
    )
        internal
        pure
        returns (uint256)
    {
        uint256 c = a + b;
        require(c >= a, "ADD_ERROR");
        return c;
    }

    function add(
        int256 a,
        uint256 b
    )
        internal
        pure
        returns (int256)
    {
        require(b <= 2**255 - 1, "INT256_ADD_ERROR");
        int256 c = a + int256(b);
        require(c >= a, "INT256_ADD_ERROR");
        return c;
    }

    // Divides two numbers and returns the remainder (unsigned integer modulo), reverts when dividing by zero.
    function mod(
        uint256 a,
        uint256 b
    )
        internal
        pure
        returns (uint256)
    {
        require(b != 0, "MOD_ERROR");
        return a % b;
    }

    /**
     * Check the amount of precision lost by calculating multiple * (numerator / denominator). To
     * do this, we check the remainder and make sure it's proportionally less than 0.1%. So we have:
     *
     *     ((numerator * multiple) % denominator)     1
     *     -------------------------------------- < ----
     *              numerator * multiple            1000
     *
     * To avoid further division, we can move the denominators to the other sides and we get:
     *
     *     ((numerator * multiple) % denominator) * 1000 < numerator * multiple
     *
     * Since we want to return true if there IS a rounding error, we simply flip the sign and our
     * final equation becomes:
     *
     *     ((numerator * multiple) % denominator) * 1000 >= numerator * multiple
     *
     * @param numerator The numerator of the proportion
     * @param denominator The denominator of the proportion
     * @param multiple The amount we want a proportion of
     * @return Boolean indicating if there is a rounding error when calculating the proportion
     */
    function isRoundingError(
        uint256 numerator,
        uint256 denominator,
        uint256 multiple
    )
        internal
        pure
        returns (bool)
    {
        // numerator.mul(multiple).mod(denominator).mul(1000) >= numerator.mul(multiple)
        return mul(mod(mul(numerator, multiple), denominator), 1000) >= mul(numerator, multiple);
    }

    /**
     * Takes an amount (multiple) and calculates a proportion of it given a numerator/denominator
     * pair of values. The final value will be rounded down to the nearest integer value.
     *
     * This function will revert the transaction if rounding the final value down would lose more
     * than 0.1% precision.
     *
     * @param numerator The numerator of the proportion
     * @param denominator The denominator of the proportion
     * @param multiple The amount we want a proportion of
     * @return The final proportion of multiple rounded down
     */
    function getPartialAmountFloor(
        uint256 numerator,
        uint256 denominator,
        uint256 multiple
    )
        internal
        pure
        returns (uint256)
    {
        require(!isRoundingError(numerator, denominator, multiple), "ROUNDING_ERROR");
        // numerator.mul(multiple).div(denominator)
        return div(mul(numerator, multiple), denominator);
    }

    /**
     * Returns the smaller integer of the two passed in.
     *
     * @param a Unsigned integer
     * @param b Unsigned integer
     * @return The smaller of the two integers
     */
    function min(
        uint256 a,
        uint256 b
    )
        internal
        pure
        returns (uint256)
    {
        return a < b ? a : b;
    }
}