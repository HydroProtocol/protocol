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

import "./Pool.sol";
import "../lib/Store.sol";
import "../lib/SafeMath.sol";
import { Types, Auction } from "../lib/Types.sol";
import "../lib/Events.sol";

library Auctions {
    using SafeMath for uint256;
    using Auction for Types.Auction;

    function fillAuction(
        Store.State storage state,
        uint256 id
    ) internal {
        Types.Auction storage auction = state.auctions[id];

        // TODO, get debt from pool;
        uint256 leftDebtAmount = 0;
        fillAuctionWithAmount(state, id, leftDebtAmount);
    }

    function fillAuctionWithAmount(
        Store.State storage state,
        uint256 id,
        uint256 repayAmount
    ) internal {
        // TODO, get debt from pool;
        uint256 leftDebtAmount = 0;

        Types.Auction storage auction = state.auctions[id];

        uint256 leftCollateralAmount = state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset];

        // TODO: market ID ???
        Pool.repay(state, loan.id, repayAmount);

        uint256 ratio = auction.ratio();

        uint256 amountToTake = leftCollateralAmount.mul(ratio).mul(repayAmount).div(leftDebtAmount.mul(100));
        uint256 amountLeft = leftCollateralAmount.mul(100 - ratio).mul(repayAmount).div(leftDebtAmount.mul(100));

        // bidder receive collateral
        state.wallets[msg.sender][auction.collateralAsset] = state.wallets[msg.sender][auction.collateralAsset].add(amountToTake);

        // left part goes to auction collateral owner borrower
        state.wallets[auction.borrower][auction.collateralAsset] = state.wallets[auction.borrower][auction.collateralAsset].add(amountLeft);

        Events.logFillAuction(id, repayAmount);

        // all debts are paid
        if (leftDebtAmount <= repayAmont) {
            Events.logAuctionFinished(id);
            account.status = Types.CollateralAccountStatus.Normal;
        }
    }

    /**
     * Create a auction for a loan and save it in global state
     *
     * @param loanAmount             Debt Amount of liquidated loan, unmodifiable
     * @param collateralAssetAmounts Assets Amounts for auction
     */
    function create(
        Store.State storage state,
        uint32 marketID,
        address borrower,
        address debtAsset,
        address collateralAsset
    )
        internal
    {
        uint32 id = state.auctionsCount++;

        Types.Auction memory auction = Types.Auction({
            id: id,
            marketID: marketID,
            startBlockNumber: uint32(block.number),
            debtAsset: debtAsset,
            collateralAsset: collateralAsset,
            borrower: borrower
        });

        state.auctions[id] = auction;

        Events.logAuctionCreate(id);
    }
}