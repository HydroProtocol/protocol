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

pragma solidity 0.4.24;

contract LibExchangeErrors {
    string constant INVALID_TRADER = "INVALID_TRADER";
    string constant INVALID_SENDER = "INVALID_SENDER";
    // Taker order and maker order can't be matched
    string constant INVALID_MATCH = "INVALID_MATCH";
    string constant INVALID_SIDE = "INVALID_SIDE";
    // Signature validation failed
    string constant INVALID_ORDER_SIGNATURE = "INVALID_ORDER_SIGNATURE";
    // Taker order is not valid
    string constant INVALID_TAKER_ORDER = "INVALID_TAKER_ORDER";
    string constant ORDER_IS_NOT_FILLABLE = "ORDER_IS_NOT_FILLABLE";
    string constant MAKER_ORDER_CAN_NOT_BE_MARKET_ORDER = "MAKER_ORDER_CAN_NOT_BE_MARKET_ORDER";
    string constant COMPLETE_MATCH_FAILED = "COMPLETE_MATCH_FAILED";
    // Taker sells more than expected base tokens
    string constant TAKER_SELL_BASE_EXCEEDED = "TAKER_SELL_BASE_EXCEEDED";
    // Taker used more than expected quote tokens in market buy
    string constant TAKER_MARKET_BUY_QUOTE_EXCEEDED = "TAKER_MARKET_BUY_QUOTE_EXCEEDED";
    // Taker buys more than expected base tokens
    string constant TAKER_LIMIT_BUY_BASE_EXCEEDED = "TAKER_LIMIT_BUY_BASE_EXCEEDED";
    string constant TRANSFER_FROM_FAILED = "TRANSFER_FROM_FAILED";
    string constant RECORD_ADDRESSES_ERROR = "RECORD_ADDRESSES_ERROR";
    string constant PERIOD_NOT_COMPLETED_ERROR = "PERIOD_NOT_COMPLETED_ERROR";
    string constant CLAIM_HOT_TOKEN_ERROR = "CLAIM_HOT_TOKEN_ERROR";
    string constant INVALID_PERIOD = "INVALID_PERIOD";

    string constant ORDER_VERSION_NOT_SUPPORTED = "ORDER_VERSION_NOT_SUPPORTED";
}