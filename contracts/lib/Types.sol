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

library Types {
    enum LoanSource {
        Pool,
        P2P
    }

    enum CollateralAccountStatus {
        Normal,
        Liquid
    }

    struct Asset {
        address tokenAddress;
        uint256 collerateRate;

        // oracle
    }

    struct LoanItem {
        address lender;
        uint16 interestRate;
        uint256 amount;
        bytes32 lenderOrderHash;
    }

    // When someone borrows some asset from a source
    // A Loan is created to record the details
    struct Loan {
        uint32 id;
        uint16 assetID;
        uint32 collateralAccountID;
        uint40 startAt;
        uint40 expiredAt;

        // in pool model, it's the commonn interest rate
        // in p2p source, it's a average interest rate
        uint16 interestRate;

        // pool or p2p
        LoanSource source;

        // amount of borrowed asset
        uint256 amount;
    }

    struct CollateralAccount {
        uint32 id;

        CollateralAccountStatus status;

        // liquidation rate
        uint16 liquidateRate;

        address owner;

        // in a margin account, there is only one loan
        // in a lending account, there will be multi loans
        uint32[] loanIDs;

        mapping(uint256 => uint256) collateralAssetAmounts;
    }

    // memory only
    struct CollateralAccountDetails {
        bool       liquidable;
        uint256[]  collateralAssetAmounts;
        Loan[]     loans;
        uint256[]  loanValues;
        uint256    loansTotalValue;
        uint256    collateralsTotalValue;
    }

    struct Auction {
        uint256 id;

        // The amount of loan when the auction is created, and it's unmodifiable.
        uint256 totalLoanAmount;

        // To calculate the ratio
        uint256 startBlockNumber;

        uint256 loanID;

        // assets under liquidated
        mapping(uint256 => uint256) assetAmounts;
    }
}

library Loan {
    function isOverdue(Types.Loan memory loan, uint256 time) internal pure returns (bool) {
        return loan.expiredAt < time;
    }
}