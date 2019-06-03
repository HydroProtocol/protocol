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
        Types.Auction storage auction = state.allAuctions[id];
        Types.Loan storage loan = state.allLoans[auction.loanID];
        fillAuctionWithAmount(state, id, loan.amount);
    }

    function fillAuctionWithAmount(
        Store.State storage state,
        uint256 id,
        uint256 repayAmount
    ) internal {
        Types.Auction storage auction = state.allAuctions[id];
        Types.Loan storage loan = state.allLoans[auction.loanID];

        // TODO repay p2p loan
        Pool.repay(state, loan.id, repayAmount);

        uint256 ratio = auction.ratio();

        // receive assets
        for (uint16 i = 0; i < state.assetsCount; i++) {
            if (auction.assetAmounts[i] == 0) {
                continue;
            }

            uint256 amountToTake = auction.assetAmounts[i].mul(ratio).mul(repayAmount).div(auction.totalLoanAmount.mul(100));
            uint256 amountLeft = auction.assetAmounts[i].mul(100 - ratio).mul(repayAmount).div(auction.totalLoanAmount.mul(100));

            // bidder receive collateral
            state.balances[msg.sender][i] = state.balances[msg.sender][i].add(amountToTake);

            // left part goes to auction.owner (borrower)
            state.balances[auction.borrower][i] = state.balances[auction.borrower][i].add(amountLeft);
        }

        Events.logFillAuction(id, repayAmount);

        if (loan.amount == 0) {
            delete state.allAuctions[id]; // TODO ??
            Events.logAuctionFinished(id);
        }
    }

    /**
     * Create a auction for a loan and save it in global state
     *
     * @param loanID                 ID of liquidated loan
     * @param loanAmount             Debt Amount of liquidated loan, unmodifiable
     * @param collateralAssetAmounts Assets Amounts for auction
     */
    function createAuction(
        Store.State storage state,
        uint32 loanID,
        address borrower,
        uint256 loanAmount,
        uint256 loanUSDValue,
        uint256 totalLoansUSDValue,
        uint256[] memory collateralAssetAmounts
    )
        internal
    {
        uint32 id = state.auctionsCount++;

        Types.Auction memory auction = Types.Auction({
            id: id,
            startBlockNumber: uint32(block.number),
            loanID: loanID,
            borrower: borrower,
            totalLoanAmount: loanAmount
        });

        state.allAuctions[id] = auction;

        for (uint256 i = 0; i < collateralAssetAmounts.length; i++ ) {
            state.allAuctions[id].assetAmounts[i] = loanUSDValue.mul(collateralAssetAmounts[i]).div(totalLoansUSDValue);
        }

        Events.logAuctionCreate(id);
    }

    function removeLoanIDFromCollateralAccount(
        Store.State storage state,
        uint256 loanID,
        uint256 accountID
    ) internal {
        Types.CollateralAccount storage account = state.allCollateralAccounts[accountID];

        for (uint32 i = 0; i < account.loanIDs.length; i++){
            if (account.loanIDs[i] == loanID) {
                account.loanIDs[i] = account.loanIDs[account.loanIDs.length-1];
                delete account.loanIDs[account.loanIDs.length - 1];
                account.loanIDs.length--;
                break;
            }
        }
    }
}