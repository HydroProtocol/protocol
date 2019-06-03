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
import "../exchange/Exchange.sol";
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

        // will move your ${collateralAmount} ${collateralAsset} into collateral account
        uint16 collateralAssetID;

        // the worst borrowing interest rate
        uint16 maxInterestRate;

        // liquidation rate for the margin position
        uint16 liquidationRate;

        // the earliest expired time;
        uint40 minExpiredAt;

        // expire time
        uint40 expiredAt;

        // trader
        address trader;

        // minExchangeAmount
        uint256 minExchangeAmount;

        uint256 borrowAmount;

        uint256 collateralAmount;

        // nonce to make same content request to have a different hash
        bytes32 nonce;
    }


    function openMargin(
        Store.State storage state,
        OpenMarginRequest memory openRequest,
        Types.ExchangeMatchParams memory params
    )
        internal
    {
        // TODO: use real rate
        uint32 accountID = CollateralAccounts.createCollateralAccount(
            state,
            openRequest.trader,
            110
        );

        // transfer collateral into account
        CollateralAccounts.depositCollateral(
            state,
            accountID,
            openRequest.collateralAssetID,
            openRequest.collateralAmount
        );

        // TODO: p2p check interest Rate and minExpiredAt
        Pool.borrow(
            state,
            accountID,
            openRequest.borrowAssetID,
            openRequest.borrowAmount,
            openRequest.maxInterestRate,
            openRequest.minExpiredAt
        );

        // save borrowed amount into account
        mapping( uint16 => uint256 ) storage accountBalances = state.allCollateralAccounts[accountID].collateralAssetAmounts;
        accountBalances[openRequest.borrowAssetID] = accountBalances[openRequest.borrowAssetID].add(openRequest.borrowAmount);

        // exchange collateral
        Exchange.exchangeMatchOrders(state, params, state.allCollateralAccounts[accountID].collateralAssetAmounts);

        validateOpen(state, openRequest, accountID);
    }

    function validateOpen(
        Store.State storage state,
        OpenMarginRequest memory openRequest,
        uint32 accountID
    ) internal {
        Types.CollateralAccount storage account = state.allCollateralAccounts[accountID];

        require(
            account.collateralAssetAmounts[openRequest.collateralAssetID] > openRequest.collateralAmount.add(openRequest.minExchangeAmount),
            "EXCHANGE_SLIPPAGE_TOO_BIG"
        );

        // account can't be liquidatable
        require(!CollateralAccounts.getCollateralAccountDetails(state, accountID).liquidable, "MARGIN_IS_LIQUIDABLE");
    }
}