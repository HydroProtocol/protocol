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

library Errors {
    ////////////////////
    // Exchange Errors//
    ////////////////////

    function INVALID_TRADER() internal pure returns (string memory) {
        return "INVALID_TRADER";
    }

    function INVALID_SENDER() internal pure returns (string memory) {
        return "INVALID_SENDER";
    }

    // Taker order and maker order can't be matched
    function INVALID_MATCH() internal pure returns (string memory) {
        return "INVALID_MATCH";
    }

    function INVALID_SIDE() internal pure returns (string memory) {
        return "INVALID_SIDE";
    }

    // Signature validation failed
    function INVALID_ORDER_SIGNATURE() internal pure returns (string memory) {
        return "INVALID_ORDER_SIGNATURE";
    }

    // Taker order is not valid
    function ORDER_IS_NOT_FILLABLE() internal pure returns (string memory) {
        return "ORDER_IS_NOT_FILLABLE";
    }

    function MAKER_ORDER_CAN_NOT_BE_MARKET_ORDER() internal pure returns (string memory) {
        return "MAKER_ORDER_CAN_NOT_BE_MARKET_ORDER";
    }

    function TRANSFER_FROM_FAILED() internal pure returns (string memory) {
        return "TRANSFER_FROM_FAILED";
    }

    function MAKER_ORDER_OVER_MATCH() internal pure returns (string memory) {
        return "MAKER_ORDER_OVER_MATCH";
    }

    function TAKER_ORDER_OVER_MATCH() internal pure returns (string memory) {
        return "TAKER_ORDER_OVER_MATCH";
    }

    function ORDER_VERSION_NOT_SUPPORTED() internal pure returns (string memory) {
        return "ORDER_VERSION_NOT_SUPPORTED";
    }

    function MAKER_ONLY_ORDER_CANNOT_BE_TAKER() internal pure returns (string memory) {
        return "MAKER_ONLY_ORDER_CANNOT_BE_TAKER";
    }
}