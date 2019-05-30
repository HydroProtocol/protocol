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


import "../GlobalStore.sol";
import "./Pool.sol";

import "../lib/SafeMath.sol";
import { Types, Auction } from "../lib/Types.sol";
import "../lib/Events.sol";

contract Auctions is GlobalStore {
    using SafeMath for uint256;
    using Auction for Types.Auction;

    function fillAuction(uint256 id) public {
        Types.Auction storage auction = state.allAuctions[id];
        Types.Loan storage loan = state.allLoans[auction.loanID];
        fillAuctionWithAmount(id, loan.amount);
    }

    function fillAuctionWithAmount(uint256 id, uint256 repayAmount) public {
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
            state.balances[i][msg.sender] = state.balances[i][msg.sender].add(amountToTake);

            // left part goes to auction.owner (borrower)
            state.balances[i][auction.borrower] = state.balances[i][auction.borrower].add(amountLeft);
        }

        Events.logFillAuction(id, repayAmount);

        if (loan.amount == 0) {
            delete state.allAuctions[id]; // TODO ??
            Events.logAuctionFinished(id);
        }
    }
}