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

    function fillAuctionWithAmount(
        Store.State storage state,
        uint32 id,
        uint256 repayAmount
    ) internal {
        Types.Auction storage auction = state.auctions[id];

        uint256 leftDebtAmount = Pool._getPoolBorrow(state, auction.debtAsset, auction.borrower, auction.marketID);
        uint256 leftCollateralAmount = state.accounts[auction.borrower][auction.marketID].wallet.balances[auction.collateralAsset];

        Types.WalletPath memory path = WalletPath.getMarketPath(msg.sender, auction.marketID);

        Pool.repay(
            state,
            path,
            auction.debtAsset,
            repayAmount
        );

        uint256 ratio = auction.ratio();

        uint256 amountToTake = leftCollateralAmount.mul(ratio).mul(repayAmount).div(leftDebtAmount.mul(100));
        uint256 amountLeft = leftCollateralAmount.mul(100 - ratio).mul(repayAmount).div(leftDebtAmount.mul(100));

        // bidder receive collateral
        state.wallets[msg.sender].balances[auction.collateralAsset] = state.wallets[msg.sender].balances[auction.collateralAsset].add(amountToTake);

        // left part goes to auction collateral owner borrower
        state.wallets[auction.borrower].balances[auction.collateralAsset] = state.wallets[auction.borrower].balances[auction.collateralAsset].add(amountLeft);

        Events.logFillAuction(id, repayAmount);

        // all debts are paid
        if (leftDebtAmount <= repayAmount) {
            Events.logAuctionFinished(id);
            Types.CollateralAccount storage account = state.accounts[auction.borrower][auction.marketID];
            account.status = Types.CollateralAccountStatus.Normal;
        }
    }

    /**
     * Create a auction for a loan and save it in global state
     *
     */
    function create(
        Store.State storage state,
        uint16 marketID,
        address borrower,
        address debtAsset,
        address collateralAsset
    )
        internal
    {
        uint32 id = state.auctionsCount++;

        Types.Auction memory auction = Types.Auction({
            id: id,
            startBlockNumber: uint32(block.number),
            marketID: marketID,
            borrower: borrower,
            debtAsset: debtAsset,
            collateralAsset: collateralAsset
        });

        state.auctions[id] = auction;

        Events.logAuctionCreate(id);
    }
}