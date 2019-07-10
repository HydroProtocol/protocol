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
pragma experimental ABIEncoderV2;

import "./Types.sol";
import "../interfaces/IPriceOracle.sol";

/**
 * Library to define store data types
 */
library Store {

    struct RelayerState {
        /**
        * Mapping of relayerAddress => delegateAddress
        */
        mapping (address => mapping (address => bool)) relayerDelegates;

        /**
        * Mapping of relayerAddress => whether relayer is opted out of the liquidity incentive system
        */
        mapping (address => bool) hasExited;
    }

    struct ExchangeState {

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
        */
        bytes32 discountConfig;

        /**
        * Mapping of orderHash => amount
        * Generally the amount will be specified in base token units, however in the case of a market
        * buy order the amount is specified in quote token units.
        */
        mapping (bytes32 => uint256) filled;

        /**
        * Mapping of orderHash => whether order has been cancelled.
        */
        mapping (bytes32 => bool) cancelled;

        address hotTokenAddress;
    }

    struct LendingPoolState {
        uint256 insuranceRatio;

        // insurance balances
        mapping(address => uint256) insuranceBalances;

        mapping (address => uint256) borrowIndex; // decimal
        mapping (address => uint256) supplyIndex; // decimal
        mapping (address => uint256) indexStartTime; // timestamp

        mapping (address => uint256) borrowAnnualInterestRate; // decimal
        mapping (address => uint256) supplyAnnualInterestRate; // decimal

        // total borrow
        mapping(address => uint256) normalizedTotalBorrow;

        // user => marketID => balances
        mapping (address => mapping (uint16 => mapping(address => uint256))) normalizedBorrow;
    }

    struct AuctionState {

        // count of auctions
        uint32 auctionsCount;

        // all auctions
        mapping(uint32 => Types.Auction) auctions;

        // current auctions
        uint32[] currentAuctions;

        // auction initiator reward ratio
        uint256 initiatorRewardRatio;
    }

    struct State {

        uint16 marketsCount;

        mapping(address => Types.Asset) assets;
        mapping(address => int256) cash;

        // user => marketID => account
        mapping(address => mapping(uint16 => Types.CollateralAccount)) accounts;

        // all markets
        mapping(uint16 => Types.Market) markets;

        // user balances
        mapping(address => mapping(address => uint256)) balances;

        LendingPoolState pool;

        ExchangeState exchange;

        RelayerState relayer;

        AuctionState auction;
    }
}