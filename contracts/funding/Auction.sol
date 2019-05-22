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

import "../lib/SafeMath.sol";
import "./Loans.sol";
import "./ProxyCaller.sol";
import "./OracleCaller.sol";
import "./Collateral.sol";
import "./Assets.sol";

contract Auction is OracleCaller, Loans, Assets, Collateral {
    using SafeMath for uint256;

    uint256 public auctionsCount = 1;
    mapping(uint256 => Auction) public allAuctions;
    mapping (address => uint256) public liquidatingAssets;

    event AuctionCreated(uint256 auctionID);
    event AuctionClaimed(uint256 auctionID, uint256 AuctionClaimed);
    event AuctionFinished(uint256 auctionID);

    struct Auction {
        uint256 id;
        uint256 startBlockNumber;
        uint256 loanID;
        uint256[] assetAmounts;
    }

    struct UserLoansState {
        bool       liquidable;
        uint256[]  userAssets;
        Loan[]     loans;
        uint256[]  loanValues;
        uint256    loansTotalValue;
        uint256    collateralsTotalValue;
    }

    function createAuction(Loan memory loan, uint256 loanValue, uint256 loansValue, uint256[] memory assetAmounts)
        internal
    {
        uint256 id = auctionsCount++;
        uint256[] memory actuionAssetAmounts = new uint256[](assetAmounts.length);

        for (uint256 i = 0; i < assetAmounts.length; i++ ) {
            actuionAssetAmounts[i] = loanValue.mul(assetAmounts[i]).div(loansValue);
        }

        Auction memory auction = Auction({
            id: id,
            startBlockNumber: block.number,
            loanID: loan.id,
            assetAmounts: actuionAssetAmounts
        });

        allAuctions[id] = auction;

        emit AuctionCreated(id);
    }

    function getAuctionRatio(Auction memory auction) internal view returns (uint256) {
        uint256 currentRatio = block.number - auction.startBlockNumber;
        return currentRatio < 100 ? currentRatio : 100;
    }

    function claimAuction(uint256 id) public {
        Auction memory auction = allAuctions[id];
        Loan memory loan = allLoans[auction.loanID];
        claimAuctionWithAmount(id, loan.amount);
    }

    function claimAuctionWithAmount(uint256 id, uint256 repayAmount) public {
        Auction memory auction = allAuctions[id];
        Loan memory loan = allLoans[auction.loanID];

        // pay debt
        repayLoan(loan, msg.sender, repayAmount);

        uint256 ratio = getAuctionRatio(auction);

        // receive assets
        for (uint256 i = 0; i < allAssets.length; i++) {
            Asset memory asset = allAssets[i];
            uint256 amount = auction.assetAmounts[i].mul(ratio).div(100);

            if (asset.tokenAddress == address(0)) {
                depositEthFor(msg.sender, amount);
            } else {
                depositTokenFor(asset.tokenAddress, msg.sender, amount);
            }
        }

        emit AuctionClaimed(id, repayAmount);

        if (loan.amount == 0) {
            delete allAuctions[id];

            emit AuctionFinished(id);
        }
    }

    function liquidateUsers(address[] memory users) public {
        for( uint256 i = 0; i < users.length; i++ ) {
            liquidateUser(users[i]);
        }
    }

    function isUserLiquidable(address user) public view returns (bool) {
        UserLoansState memory state = getUserLoansState(user);
        return state.liquidable;
    }

    function getAssetAmountValue(address asset, uint256 amount) internal view returns (uint256) {
        uint256 price = getTokenPriceInEther(asset);
        return price.mul(amount).div(ORACLE_PRICE_BASE);
    }

    function getUserLoansState(address user)
        public view
        returns ( UserLoansState memory state )
    {
        state.userAssets = new uint256[](allAssets.length);

        for (uint256 i = 0; i < allAssets.length; i++) {
            address tokenAddress = allAssets[i].tokenAddress;
            uint256 amount = collaterals[tokenAddress][user];
            state.collateralsTotalValue = state.collateralsTotalValue.add(getAssetAmountValue(tokenAddress, amount));
            state.userAssets[i] = amount;
        }

        state.loans = getBorrowerLoans(user);

        if (state.loans.length <= 0) {
            return state;
        }

        state.loanValues = new uint256[](state.loans.length);


        for (uint256 i = 0; i < state.loans.length; i++) {
            state.loanValues[i] = getAssetAmountValue(state.loans[i].asset, state.loans[i].amount);
            state.loansTotalValue = state.loansTotalValue.add(state.loanValues[i]);
        }

        state.liquidable = state.collateralsTotalValue < state.loansTotalValue.mul(150).div(100);
    }

    function liquidateUser(address user) public returns (bool) {
        UserLoansState memory state = getUserLoansState(user);

        if (!state.liquidable) {
            return false;
        }

        // storage changes

        for (uint256 i = 0; i < state.loans.length; i++ ) {
            createAuction(state.loans[i], state.loanValues[i], state.loansTotalValue, state.userAssets);
        }

        // confiscate all collaterals
        // transfer all user collateral to liquidatingAssets;
        for (uint256 i = 0; i < allAssets.length; i++) {
            Asset memory asset = allAssets[i];
            collaterals[asset.tokenAddress][user] = 0;
            liquidatingAssets[asset.tokenAddress] = liquidatingAssets[asset.tokenAddress].add(state.userAssets[i]);
        }

        return true;
    }
}