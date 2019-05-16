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
import "./Collateral.sol";
import "./Assets.sol";

contract Auctions is Loans, Assets, Collateral {
    using SafeMath for uint256;

    uint256 public auctionsCount;
    mapping(uint256 => Auction) public allAuctions;
    mapping(address => uint256) public borrowerAuction;

    event UserLiquidated(address user, uint256 blockNumber);

    struct Auction {
        uint256 id;
        uint256 startBlockNumber;
        address borrower;
        uint256[] loanIDs;
    }

    modifier userHasNoAuction(address user) {
        require(borrowerAuction[user] == 0, "User is ready have an auction");
        _;
    }

    function createAuction(uint256[] memory loanIDs, address borrower)
        internal
        userHasNoAuction(borrower)
    {
        uint256 id = auctionsCount + 1; // id start from 1
        auctionsCount++;

        Auction memory auction = Auction({
            id: id,
            startBlockNumber: block.number,
            borrower: borrower,
            loanIDs: loanIDs
        });

        allAuctions[id] = auction;
        borrowerAuction[auction.borrower] = id;

        emit UserLiquidated(borrower, block.number);
    }

    function getAuctionRatio(Auction memory auction) internal view returns (uint256) {
        return block.number - auction.startBlockNumber;
    }

    function closeAuction(uint256 id) public {
        Auction memory auction = allAuctions[id];
        Loan[] memory loans = getLoansByIDs(auction.loanIDs);

        for (uint256 i = 0; i < loans.length; i++) {
            Loan memory loan = loans[i];
            repayLoan(loan, msg.sender, loan.amount); // to allow partial repayLoan
        }

        uint256 ratio = getAuctionRatio(auction);

        for (uint256 i = 0; i < allAssets.length; i++) {
            Asset memory asset = allAssets[i];
            uint256 amount = colleterals[asset.tokenAddress][auction.borrower].mul(ratio); // TODO base unit
            withdrawCollateralToProxy(asset.tokenAddress, auction.borrower, amount);
            transferFrom(asset.tokenAddress, auction.borrower, msg.sender, amount);
        }

        // TODO if all debt are paid
        // delete allAutions[id]
        // delete borrowAuction[id]
    }

    function liquidateUsers(address[] memory users) public {
        for( uint256 i = 0; i < users.length; i++ ) {
            liquidateUser(users[i]);
        }
    }

    function isUserLiquidable(address user) public view returns (bool) {
        return getOrderLiquidableLoans(user).length > 0;
    }

    function liquidateUser(address user) public {
        Loan[] memory loans = getOrderLiquidableLoans(user);

        if (loans.length <= 0) {
            return;
        }

        uint256[] memory ids = new uint256[](loans.length);

        for (uint256 i = 0; i < loans.length; i++ ) {
            ids[i] = loans[i].id;
        }

        createAuction(ids, user);
    }

    function getOrderLiquidableLoans(address user) internal view returns (Loan[] memory loans) {
        if (loansByBorrower[user].length <= 0) {
            return loans;
        }

        bool globalLiquidation = false; // TODO check global liquidation

        if (globalLiquidation) {
            return getBorrowerLoans(user);
        }

        return getBorrowerOverdueLoans(user);
    }
}