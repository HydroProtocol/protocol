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

import "./Pool.sol";
import "./CollateralAccounts.sol";
// import "../lib/Consts.sol";
import "../lib/Types.sol";
import "../lib/Store.sol";
import "../lib/SafeMath.sol";

library Margin {
    using SafeMath for uint256;

    // struct types

    // struct BorrowingRequest {
    //     uint40 durations;
    //     uint16 maxInterestRate;
    //     address from;
    //     uint256 amount;
    // }

    // struct BorrowResponse {
    //     uint16 interestRate;
    //     uint40 deadline;
    //     address owner;
    //     uint256 amount;
    // }

    // user sign this struct as his will to open an market
    // TODO tie spaces
    struct OpenMarginRequest {
        // will borrow ${borrowAmount} ${borrowAsset} from a funding source
        uint16 borrowAssetID;
        uint256 borrowAmount;

        // will move your ${collateralAmount} ${collateralAsset} into collateral account
        uint16 collateralAssetID;
        uint256 collateralAmount;

        // the worst borrowing interest rate
        uint16 maxInterestRate;

        // the earliest expired time;
        uint16 minExpiredAt;

        // trader
        address trader;
        // expire time
        uint40 expiredAt;
        // liquidation rate for the margin position
        uint16 liquidationRate;
        // nonce to make same content request to have a different hash
        bytes32 nonce;
    }


    function openMargin(
        Store.State storage state,
        OpenMarginRequest memory openRequest
    )
        internal
    {
        // TODO: use real rate
        uint32 accountID = CollateralAccounts.createCollateralAccount(
            state,
            openRequest.trader,
            110
        );

        // transfer
        CollateralAccounts.depositCollateral(
            state,
            accountID,
            openRequest.collateralAssetID,
            openRequest.collateralAmount
        );

        uint32 loanID = Pool.borrow(
            state,
            accountID,
            openRequest.borrowAssetID,
            openRequest.borrowAmount,
            openRequest.maxInterestRate,
            openRequest.minExpiredAt
        );

        // exchange(openReq.exchangeParams);
        // requrei at least has borrow + minExchangedAmount in collateralAccount, and liquidity rate is ...

        // bind account and loan
        state.allCollateralAccounts[accountID].loanIDs.push(loanID);
    }
}