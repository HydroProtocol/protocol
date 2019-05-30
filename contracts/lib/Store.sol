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
    struct PoolState {
        uint256 poolAnnualInterest;
        uint40 poolInterestStartTime;

        // total suppy and borrow
        mapping (uint16 => uint256) totalSupply;
        mapping (uint16 => uint256) totalBorrow;

        // assetID => total shares
        mapping (uint16 => uint256) totalSupplyShares;

        // assetID => user => shares
        mapping (uint16 => mapping (address => uint256)) supplyShares;
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
        mapping (uint16 => mapping (address => uint)) balances;

        PoolState pool;
    }
}