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

import "./LendingPool.sol";
import "../lib/Store.sol";
import "../lib/SafeMath.sol";
import "../lib/Types.sol";
import "../lib/Events.sol";
import "../lib/Decimal.sol";
import "../lib/Transfer.sol";

library Auctions {
    using SafeMath for uint256;
    using Auction for Types.Auction;

    /**
     * Anyone can call this method to help repay part or all of an owed amount,
     * in exchange for an proportionate amount of collateral.
     * Generally called by an arbitrageur for profit, which incidentally keeps the liquidation mechanism efficient.
     *
     */
    function fillAuction(
        Store.State storage state,
        uint32 auctionID,
        uint256 repayAmount
    )
        internal
    {
        Types.Auction storage auction = state.auction.auctions[auctionID];

        // get remaining debt
        uint256 remainingDebt = LendingPool.getBorrowOf(
            state,
            auction.debtAsset,
            auction.borrower,
            auction.marketID
        );

        // get remaining collateral
        uint256 remainingCollateral = state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset];

        // make sure msg.sender cannot repay an amount greater than the actual remaining debt
        validRepayAmount = repayAmount < remainingDebt ? repayAmount : remainingDebt;

        // update the debt after repayment
        state.balances[msg.sender][auction.debtAsset] = SafeMath.sub(
            state.balances[msg.sender][auction.debtAsset],
            validRepayAmount
        );

        // borrower temporarily gets the repayment amount
        state.accounts[auction.borrower][auction.marketID].balances[auction.debtAsset] = SafeMath.add(
            state.accounts[auction.borrower][auction.marketID].balances[auction.debtAsset],
            validRepayAmount
        );

        // borrower pays back to the lending pool
        LendingPool.repay(
            state,
            auction.borrower,
            auction.marketID,
            auction.debtAsset,
            repayAmount
        );

        // compute how much collateral is divided up amongst the bidder, auction initiator, and borrower
        uint256 ratio = auction.ratio(state);
        uint256 liquidatedCollateral = remainingCollateral.mul(validRepayAmount).div(remainingDebt);

        uint256 amountForBidder = Decimal.mul(liquidatedCollateral, ratio);
        uint256 amountForInitiator = Decimal.mul(liquidatedCollateral.sub(amountForBidder), state.auction.initiatorRewardRatio);
        uint256 amountForBorrower = liquidatedCollateral.sub(amountForBidder).sub(amountForInitiator);

        // update remaining collateral ammount
        state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset] = SafeMath.sub(
            state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset],
            liquidatedCollateral
        );

        // send a portion of collateral to the bidder
        state.balances[msg.sender][auction.collateralAsset] = SafeMath.add(
            state.balances[msg.sender][auction.collateralAsset],
            amountForBidder
        );

        // send a portion of collateral to the initiator
        state.balances[auction.initiator][auction.collateralAsset] = SafeMath.add(
            state.balances[auction.initiator][auction.collateralAsset],
            amountForInitiator
        );

        // send a portion of collateral to the borrower
        state.balances[auction.borrower][auction.collateralAsset] = SafeMath.add(
            state.balances[auction.borrower][auction.collateralAsset],
            amountForBorrower
        );

        // emit fillAuction event
        Events.logFillAuction(auctionID, validRepayAmount);

        // lastly if all debts are settled, end the auction
        if (remainingDebt <= repayAmount) {
            endAuction(state, auctionID);
        }
    }

    /**
     * An auction is 'expired' if it remains unfilled at the end of the allocated time.
     * In this case, the auction should be closed.
     * The insurance mechanism will try to cover the loss, and in return take the collateral.
     * If losses remain after insurance is exhausted, the amount is socialized by all lenders in the lending pool.
     *
     */
    function closeExpiredAuction(
        Store.State storage state,
        uint32 auctionID
    )
        internal
    {
        Types.Auction storage auction = state.auction.auctions[auctionID];

        //check the auction is expired(not in progress, but not filled)
        require(auction.status == Types.AuctionStatus.InProgress, "AUCTION_NOT_IN_PROGRESS");
        require(auction.ratio(state) == Decimal.one(), "AUCTION_NOT_END");

        // ask the insurance pool to compensate the loss
        // note: this will hand over all collateral to the insurance pool
        uint256 compensationAmount = LendingPool.compensate(
            state,
            auction.borrower,
            auction.marketID,
            auction.debtAsset,
            auction.collateralAsset
        );

        // repay with insurance compensation
        LendingPool.repay(
            state,
            auction.borrower,
            auction.marketID,
            auction.debtAsset,
            compensationAmount
        );

        // get remaining debt
        uint256 remainingDebt = LendingPool.getBorrowOf(
            state,
            auction.debtAsset,
            auction.borrower,
            auction.marketID
        );

        // If there are still debt remaining (because insurance couldn't cover)
        // then losses are shared by all lenders
        if (remainingDebt > 0){
            LendingPool.socializeLoss(
                state,
                auction.borrower,
                auction.marketID,
                auction.debtAsset,
                remainingDebt
            );
        }

        //lastly, end the auction
        endAuction(state, auctionID);
    }

    function endAuction(
        Store.State storage state,
        uint32 auctionID
    )
        internal
    {
        Types.Auction storage auction = state.auction.auctions[auctionID];
        auction.status = Types.AuctionStatus.Finished;

        Types.CollateralAccount storage account = state.accounts[auction.borrower][auction.marketID];
        account.status = Types.CollateralAccountStatus.Normal;

        for (uint i = 0; i < state.auction.currentAuctions.length; i++){
            if (state.auction.currentAuctions[i] == auctionID){
                state.auction.currentAuctions[i] = state.auction.currentAuctions[state.auction.currentAuctions.length-1];
                state.auction.currentAuctions.length--;
            }
        }

        Events.logAuctionFinished(auctionID);
    }

    /**
     * Create an auction and save it in global state
     *
     */
    function create(
        Store.State storage state,
        uint16 marketID,
        address borrower,
        address initiator,
        address debtAsset,
        address collateralAsset
    )
        internal
        returns (uint32)
    {
        uint32 id = state.auction.auctionsCount++;

        Types.Auction memory auction = Types.Auction({
            id: id,
            status: Types.AuctionStatus.InProgress,
            startBlockNumber: uint32(block.number),
            marketID: marketID,
            borrower: borrower,
            initiator: initiator,
            debtAsset: debtAsset,
            collateralAsset: collateralAsset
        });

        state.auction.auctions[id] = auction;
        state.auction.currentAuctions.push(id);

        Events.logAuctionCreate(id);

        return id;
    }

    function getAuctionDetails(
        Store.State storage state,
        uint32 auctionID
    )
        internal
        view
        returns (Types.AuctionDetails memory details)
    {
        Types.Auction memory auction = state.auction.auctions[auctionID];

        details.debtAsset = auction.debtAsset;
        details.collateralAsset = auction.collateralAsset;

        details.leftDebtAmount = LendingPool.getBorrowOf(
            state,
            auction.debtAsset,
            auction.borrower,
            auction.marketID
        );

        details.leftCollateralAmount = state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset];
        details.ratio = auction.ratio(state);
    }
}