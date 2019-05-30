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

import "./SafeMath.sol";
import "../interfaces/OracleInterface.sol";

library Types {
    enum LoanSource {
        Pool,
        P2P
    }

    enum CollateralAccountStatus {
        Normal,
        Liquid,
        Closed
    }

    struct Asset {
        address tokenAddress;
        uint256 collateralRate;
        OracleInterface oracle;
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

        // assetID => assetAmount
        mapping(uint16 => uint256) collateralAssetAmounts;
    }

    // memory only
    struct CollateralAccountDetails {
        bool       liquidable;
        uint256[]  collateralAssetAmounts;
        Loan[]     loans;
        uint256[]  loanValues;
        uint256    loansTotalUSDValue;
        uint256    collateralsTotalUSDlValue;
    }

    struct Auction {
        uint32 id;
        // To calculate the ratio
        uint32 startBlockNumber;

        uint32 loanID;

        address borrower;

        // The amount of loan when the auction is created, and it's unmodifiable.
        uint256 totalLoanAmount;

        // assets under liquidated, and it's unmodifiable.
        mapping(uint256 => uint256) assetAmounts;
    }
}

library Asset {
    function getPrice(Types.Asset storage asset) internal view returns (uint256) {
        return asset.oracle.getPrice(asset.tokenAddress);
    }
}

library Loan {
    using SafeMath for uint256;

    function isOverdue(Types.Loan memory loan, uint256 time) internal pure returns (bool) {
        return loan.expiredAt < time;
    }

    /**
     * Get loan interest with given amount and timestamp
     * Result should divide (Consts.INTEREST_RATE_BASE * Consts.SECONDS_OF_YEAR)
     */
    function interest(Types.Loan memory loan, uint256 amount, uint40 currentTimestamp) internal pure returns (uint256) {
        uint40 timeDelta = currentTimestamp - loan.startAt;
        return amount.mul(loan.interestRate).mul(timeDelta);
    }
}

library Auction {
    function ratio(Types.Auction memory auction) internal view returns (uint256) {
        uint256 currentRatio = block.number - auction.startBlockNumber;
        return currentRatio < 100 ? currentRatio : 100;
    }
}