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

import "../lib/Store.sol";
import "../lib/Types.sol";
import "../lib/Events.sol";
import "../lib/Decimal.sol";
import "../lib/SafeMath.sol";
import "../lib/Transfer.sol";

import "./LendingPool.sol";
import "./CollateralAccounts.sol";

/**
 * Independently deployment library to liquidate unhealthy collateral accounts and handle auctions.
 */
library Auctions {
    using SafeMath for uint256;
    using SafeMath for int256;
    using Auction for Types.Auction;

    /**
     * Liquidate a collateral account
     */
    function liquidate(
        Store.State storage state,
        address user,
        uint16 marketID
    )
        external
        returns (bool, uint32)
    {
        // if the account is in liquidate progress, liquidatable will be false
        Types.CollateralAccountDetails memory details = CollateralAccounts.getDetails(
            state,
            user,
            marketID
        );

        require(details.liquidatable, "ACCOUNT_NOT_LIQUIDABLE");

        Types.Market storage market = state.markets[marketID];
        Types.CollateralAccount storage account = state.accounts[user][marketID];

        LendingPool.repay(
            state,
            user,
            marketID,
            market.baseAsset,
            account.balances[market.baseAsset]
        );

        LendingPool.repay(
            state,
            user,
            marketID,
            market.quoteAsset,
            account.balances[market.quoteAsset]
        );

        address collateralAsset;
        address debtAsset;

        uint256 leftBaseAssetDebt = LendingPool.getAmountBorrowed(
            state,
            market.baseAsset,
            user,
            marketID
        );

        uint256 leftQuoteAssetDebt = LendingPool.getAmountBorrowed(
            state,
            market.quoteAsset,
            user,
            marketID
        );

        bool hasAution = !(leftBaseAssetDebt == 0 && leftQuoteAssetDebt == 0);

        Events.logLiquidate(
            user,
            marketID,
            hasAution
        );

        if (!hasAution) {
            // no auction
            return (false, 0);
        }

        account.status = Types.CollateralAccountStatus.Liquid;

        if(account.balances[market.baseAsset] > 0) {
            // quote asset is debt, base asset is collateral
            collateralAsset = market.baseAsset;
            debtAsset = market.quoteAsset;
        } else {
            // base asset is debt, quote asset is collateral
            collateralAsset = market.quoteAsset;
            debtAsset = market.baseAsset;
        }

        uint32 newAuctionID = create(
            state,
            marketID,
            user,
            msg.sender,
            debtAsset,
            collateralAsset
        );

        return (true, newAuctionID);
    }

    /**
     * The overwhelming of auctions in practice falls into this case.
     * Given the constrant that collateral > debt, once the debt is paid of, the remaining collateral is divided
     * between the borrower and the initiator.
     */
    function fillHealthyAuction(
        Store.State storage state,
        Types.Auction storage auction,
        uint256 ratio,
        uint256 repayAmount
    )
        private
        returns (uint256, uint256) // bidderRepay collateral
    {
        uint256 leftDebtAmount = LendingPool.getAmountBorrowed(
            state,
            auction.debtAsset,
            auction.borrower,
            auction.marketID
        );

        // get remaining collateral
        uint256 leftCollateralAmount = state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset];

        state.accounts[auction.borrower][auction.marketID].balances[auction.debtAsset] = repayAmount;

        // borrower pays back to the lending pool
        uint256 actualRepayAmount = LendingPool.repay(
            state,
            auction.borrower,
            auction.marketID,
            auction.debtAsset,
            repayAmount
        );

        state.accounts[auction.borrower][auction.marketID].balances[auction.debtAsset] = 0;

        // compute how much collateral is divided up amongst the bidder, auction initiator, and borrower
        state.balances[msg.sender][auction.debtAsset] = SafeMath.sub(
            state.balances[msg.sender][auction.debtAsset],
            actualRepayAmount
        );

        uint256 collateralToProcess = leftCollateralAmount.mul(actualRepayAmount).div(leftDebtAmount);
        uint256 collateralForBidder = Decimal.mulFloor(collateralToProcess, ratio);

        uint256 collateralForInitiator = Decimal.mulFloor(collateralToProcess.sub(collateralForBidder), state.auction.initiatorRewardRatio);
        uint256 collateralForBorrower = collateralToProcess.sub(collateralForBidder).sub(collateralForInitiator);

        // update remaining collateral ammount
        state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset] = SafeMath.sub(
            state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset],
            collateralToProcess
        );

        // send a portion of collateral to the bidder
        state.balances[msg.sender][auction.collateralAsset] = SafeMath.add(
            state.balances[msg.sender][auction.collateralAsset],
            collateralForBidder
        );

        // send a portion of collateral to the initiator
        state.balances[auction.initiator][auction.collateralAsset] = SafeMath.add(
            state.balances[auction.initiator][auction.collateralAsset],
            collateralForInitiator
        );

        // send a portion of collateral to the borrower
        state.balances[auction.borrower][auction.collateralAsset] = SafeMath.add(
            state.balances[auction.borrower][auction.collateralAsset],
            collateralForBorrower
        );

        // withdraw collateralForBorrower to borrower's wallet account
        Transfer.withdraw(
            state,
            auction.borrower,
            auction.collateralAsset,
            collateralForBorrower
        );

        return (actualRepayAmount, collateralForBidder);
    }

    /**
     * In the case where the collateral is no longer valuable enough to cover the debt,
     * subsidies kicks in. Participant can bid for the entire collateral
     * for only paying part of the debt. The remaining debt is subsidized by the insurance pool
     */
    function fillBadAuction(
        Store.State storage state,
        Types.Auction storage auction,
        uint256 ratio,
        uint256 bidderRepayAmount
    )
        private
        returns (uint256, uint256, uint256) // totalRepay bidderRepay collateral
    {

        uint256 leftDebtAmount = LendingPool.getAmountBorrowed(
            state,
            auction.debtAsset,
            auction.borrower,
            auction.marketID
        );

        uint256 leftCollateralAmount = state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset];

        uint256 repayAmount = Decimal.mulFloor(bidderRepayAmount, ratio);

        state.accounts[auction.borrower][auction.marketID].balances[auction.debtAsset] = repayAmount;

        uint256 actualRepayAmount = LendingPool.repay(
            state,
            auction.borrower,
            auction.marketID,
            auction.debtAsset,
            repayAmount
        );

        state.accounts[auction.borrower][auction.marketID].balances[auction.debtAsset] = 0; // recover unused principal

        uint256 actualBidderRepay = bidderRepayAmount;

        if (actualRepayAmount < repayAmount) {
            actualBidderRepay = Decimal.divCeil(actualRepayAmount, ratio);
        }

        // gather repay capital
        LendingPool.claimInsurance(state, auction.debtAsset, actualRepayAmount.sub(actualBidderRepay));

        state.balances[msg.sender][auction.debtAsset] = SafeMath.sub(
            state.balances[msg.sender][auction.debtAsset],
            actualBidderRepay
        );

        // update collateralAmount
        uint256 collateralForBidder = leftCollateralAmount.mul(actualRepayAmount).div(leftDebtAmount);

        state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset] = SafeMath.sub(
            state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset],
            collateralForBidder
        );

        // bidder receive collateral
        state.balances[msg.sender][auction.collateralAsset] = SafeMath.add(
            state.balances[msg.sender][auction.collateralAsset],
            collateralForBidder
        );

        return (actualRepayAmount, actualBidderRepay, collateralForBidder);
    }

    // ensure repay no more than repayAmount
    function fillAuctionWithAmount(
        Store.State storage state,
        uint32 auctionID,
        uint256 repayAmount
    )
        external
    {
        Types.Auction storage auction = state.auction.auctions[auctionID];
        uint256 ratio = auction.ratio(state);

        uint256 actualRepayAmount;
        uint256 actualBidderRepayAmount;
        uint256 collateralForBidder;

        if (ratio <= Decimal.one()) {
            (actualRepayAmount, collateralForBidder) = fillHealthyAuction(state, auction, ratio, repayAmount);
            actualBidderRepayAmount = actualRepayAmount;
        } else {
            (actualRepayAmount, actualBidderRepayAmount, collateralForBidder) = fillBadAuction(state, auction, ratio, repayAmount);
        }

        // reset account state if all debts are paid
        uint256 leftDebtAmount = LendingPool.getAmountBorrowed(
            state,
            auction.debtAsset,
            auction.borrower,
            auction.marketID
        );

        Events.logFillAuction(auction.id, msg.sender, actualRepayAmount, actualBidderRepayAmount, collateralForBidder, leftDebtAmount);

        if (leftDebtAmount == 0) {
            endAuction(state, auction);
        }
    }

    /**
     * Mark an auction as finished.
     * An auction typically ends either when it becomes fully filled, or when it expires and is closed
     */
    function endAuction(
        Store.State storage state,
        Types.Auction storage auction
    )
        private
    {
        auction.status = Types.AuctionStatus.Finished;

        state.accounts[auction.borrower][auction.marketID].status = Types.CollateralAccountStatus.Normal;

        for (uint i = 0; i < state.auction.currentAuctions.length; i++) {
            if (state.auction.currentAuctions[i] == auction.id) {
                state.auction.currentAuctions[i] = state.auction.currentAuctions[state.auction.currentAuctions.length-1];
                state.auction.currentAuctions.length--;
                return;
            }
        }
    }

    /**
     * Create a new auction and save it in global state
     */
    function create(
        Store.State storage state,
        uint16 marketID,
        address borrower,
        address initiator,
        address debtAsset,
        address collateralAsset
    )
        private
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

    // price = debt / collateral / ratio
    function getAuctionDetails(
        Store.State storage state,
        uint32 auctionID
    )
        external
        view
        returns (Types.AuctionDetails memory details)
    {
        Types.Auction memory auction = state.auction.auctions[auctionID];

        details.borrower = auction.borrower;
        details.marketID = auction.marketID;
        details.debtAsset = auction.debtAsset;
        details.collateralAsset = auction.collateralAsset;

        if (state.auction.auctions[auctionID].status == Types.AuctionStatus.Finished){
            details.finished = true;
        } else {
            details.finished = false;
            details.leftDebtAmount = LendingPool.getAmountBorrowed(
                state,
                auction.debtAsset,
                auction.borrower,
                auction.marketID
            );
            details.leftCollateralAmount = state.accounts[auction.borrower][auction.marketID].balances[auction.collateralAsset];

            details.ratio = auction.ratio(state);

            if (details.leftCollateralAmount != 0 && details.ratio != 0) {
                // price = debt/collateral/ratio
                details.price = Decimal.divFloor(Decimal.divFloor(details.leftDebtAmount, details.leftCollateralAmount), details.ratio);
            }
        }
    }
}