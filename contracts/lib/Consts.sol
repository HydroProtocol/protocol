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

library Consts {
    // uint256 public constant SECONDS_OF_YEAR = 31536000;
    // uint256 public constant INTEREST_RATE_BASE = 10000;
    // uint256 public constant FEE_RATE_BASE = 10000;
    // uint256 public constant RELAYER_FEE_RATE_BASE = 10000;
    // uint256 public constant SIMULIZED_GAS_COST = 300000;
    // uint256 public constant ORACLE_PRICE_BASE = 1000000000000000000;
    // uint256 public constant LIQUIDATE_RATE_BASE = 100;
    // address public constant ETHEREUM_TOKEN_ADDRESS = address(0);

    function SECONDS_OF_YEAR() internal pure returns (uint256) {
        return 31536000;
    }

    function INTEREST_RATE_BASE() internal pure returns (uint256) {
        return 10000;
    }

    function FEE_RATE_BASE() internal pure returns (uint256) {
        return 10000;
    }

    function COLLATERAL_RATE_BASE() internal pure returns (uint256) {
        return 10000;
    }

    function RELAYER_FEE_RATE_BASE() internal pure returns (uint256) {
        return 10000;
    }

    function SIMULIZED_GAS_COST() internal pure returns (uint256) {
        return 300000;
    }

    function ORACLE_PRICE_BASE() internal pure returns (uint256) {
        return 1000000000000000000;
    }

    function LIQUIDATE_RATE_BASE() internal pure returns (uint256) {
        return 100;
    }

    function ETHEREUM_TOKEN_ADDRESS() internal pure returns (address) {
        return address(0);
    }

    /////////////////////
    // EXCHANGE CONSTS //
    /////////////////////

    function EXCHANGE_FEE_RATE_BASE() internal pure returns (uint256) {
        return 100000;
    }

    /* Order v2 data is uncompatible with v1. This contract can only handle v2 order. */
    function SUPPORTED_ORDER_VERSION() internal pure returns (uint256) {
        return 2;
    }

    // The base discounted rate is 100% of the current rate, or no discount.
    function DISCOUNT_RATE_BASE() internal pure returns (uint256) {
        return 100;
    }

    function REBATE_RATE_BASE() internal pure returns (uint256) {
        return 100;
    }
}