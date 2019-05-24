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
import "./Assets.sol";
import "../interfaces/EIP20Interface.sol";

contract Auctions is OracleCaller, Loans, Assets {
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
        uint256[]  collateralAssetAmounts;
        Loan[]     loans;
        uint256[]  loanValues;
        uint256    loansTotalValue;
        uint256    collateralsTotalValue;
    }

    function createAuction(Loan memory loan, uint256 loanValue, uint256 loansValue, uint256[] memory collateralAssetAmounts)
        internal
    {
        uint256 id = auctionsCount++;
        uint256[] memory actuionAssetAmounts = new uint256[](collateralAssetAmounts.length);

        for (uint256 i = 0; i < collateralAssetAmounts.length; i++ ) {
            actuionAssetAmounts[i] = loanValue.mul(collateralAssetAmounts[i]).div(loansValue);
        }

        Auction memory auction = Auction({
            id: id,
            startBlockNumber: block.number,
            loanID: loan.id,
            assetAmounts: actuionAssetAmounts
        });

        allAuctions[id] = auction;
        unlinkLoanAndUser(loan.id, loan.borrower);

        emit AuctionCreated(id);
    }

    function getAuctionRatio(Auction memory auction) internal view returns (uint256) {
        uint256 currentRatio = block.number - auction.startBlockNumber;
        return currentRatio < 100 ? currentRatio : 100;
    }
}