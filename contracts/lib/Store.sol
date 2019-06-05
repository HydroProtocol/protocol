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

pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import { Types } from "./Types.sol";

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
        * @param user The user address to calculate a fee discount for.
        * @return The percentage of the regular fee this user will pay.
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
    }

    struct PoolState {
        mapping (uint16 => uint256) borrowIndex;
        mapping (uint16 => uint256) supplyIndex;
        mapping (uint16 => uint256) indexStartTime;

        mapping (uint16 => uint256) borrowAnnualInterestRate;
        mapping (uint16 => uint256) supplyAnnualInterestRate;

        // total suppy and borrow
        mapping (uint16 => uint256) logicTotalSupply;
        mapping (uint16 => uint256) logicTotalBorrow;

        // assetID => user => supply
        mapping (uint16 => mapping (address => uint256)) logicSupply;

        // assetID => accountID => borrow
        mapping (uint16 => mapping (uint32 => uint256)) logicBorrow;
    }

    struct State {
        // count of collateral accounts
        uint32 collateralAccountCount;

        // count of loans
        uint32 loansCount;

        // count of assets
        uint16 assetsCount;

        // count of auctions
        uint32 auctionsCount;

        address hotTokenAddress;

        // all collateral accounts
        mapping(uint256 => Types.CollateralAccount) allCollateralAccounts;

        // user default collateral account
        mapping(address => uint256) userDefaultCollateralAccounts;

        // all supported assets
        mapping(uint256 => Types.Asset) assets;

        // all loans
        mapping(uint256 => Types.Loan) allLoans;

        // p2p loan items
        mapping(uint256 => Types.LoanItem[]) loanDetail;

        // all auctions
        mapping(uint256 => Types.Auction) allAuctions;

        /**
         * Free Balances, Can be used to
         *   1) Common trade
         *   2) Lend in p2p funding
         *   3) Margin trade as collateral
         *   4) Deposit to pool to win interest
         *   5) Withdraw to your address
         *
         * first key is asset address, second key is user address
         */
        mapping (address => mapping ( uint16 => uint)) balances;

        mapping (bytes32 => bool) usedOpenMarginRequests;

        PoolState pool;

        ExchangeState exchange;

        RelayerState relayer;
    }
}