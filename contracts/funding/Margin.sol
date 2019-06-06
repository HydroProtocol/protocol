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

    function open(
        Store.State storage state,
        OpenMarginRequest memory openRequest,
        Types.ExchangeMatchParams memory params
    )
        internal
    {
        // TODO: use real rate
        uint32 accountID = CollateralAccounts.create(
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

        // TODO: check interest Rate and minExpiredAt in p2p mode
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
        Types.ExchangeSettleResult memory settleResult = Exchange.exchangeMatchOrders(
            state,
            params,
            state.allCollateralAccounts[accountID].collateralAssetAmounts
        );

        // the exchange must have collateral asset token as income token
        require(
            settleResult.incomeToken == state.assets[openRequest.collateralAssetID].tokenAddress,
            "WRONG_INCOME_TOKEN"
        );

        // the exchange must have borrow asset token as output token
        require(
            settleResult.outputToken == state.assets[openRequest.borrowAssetID].tokenAddress,
            "WRONG_OUTPUT_TOKEN"
        );

        // the exchange must spend all borrowed tokens
        require(
            settleResult.outputTokenAmount == openRequest.borrowAmount,
            "BORROWED_AMOUNT_MUST_BE_TRADED"
        );

        // the exchange must get enough income tokens
        require(
            settleResult.incomeTokenAmount >= openRequest.minExchangeAmount,
            "EXCHANGE_SLIPPAGE_TOO_BIG"
        );

        validateAccount(state, accountID);
    }

    function validateAccount(
        Store.State storage state,
        uint32 accountID
    )
        internal
        view
    {
        // account can't be liquidatable
        require(
            !CollateralAccounts.getCollateralAccountDetails(state, accountID).liquidable,
            "MARGIN_IS_LIQUIDABLE"
        );
    }

    struct CloseMarginRequest {
        uint32 accountID;
        uint16 assetID;
        uint256 amount;
        uint256 minExchangeAmount;
    }

    function close(
        Store.State storage state,
        CloseMarginRequest memory closeRequest,
        Types.ExchangeMatchParams memory params
    )
        internal
    {
        Types.CollateralAccount storage account = state.allCollateralAccounts[closeRequest.accountID];

        // TODO allow liquidatble ?
        Types.CollateralAccountDetails memory details = CollateralAccounts.getCollateralAccountDetails(state, closeRequest.accountID);

        // close ratio
        // uint256 closeRatio = amountUSDValue.details.collateralsTotalUSDlValue

        // exchange collateral
        // TODO: verify the exchange is happened in correct market. and no unexpected trades.
        Types.ExchangeSettleResult memory settleResult = Exchange.exchangeMatchOrders(
            state, params, state.allCollateralAccounts[closeRequest.accountID].collateralAssetAmounts);

        // the exchange must have collateral asset token as income token
        require(
            settleResult.incomeToken == state.assets[state.allLoans[account.loanIDs[0]].assetID].tokenAddress,
            "WRONG_INCOME_TOKEN"
        );

        // the exchange must have borrow asset token as output token
        require(
            settleResult.outputToken == state.assets[closeRequest.assetID].tokenAddress,
            "WRONG_OUTPUT_TOKEN"
        );

        // the exchange must spend all borrowed tokens
        require(
            settleResult.outputTokenAmount == closeRequest.amount,
            "CLOSED_AMOUNT_MUST_BE_TRADED"
        );

        // the exchange must get enough income tokens
        require(
            settleResult.incomeTokenAmount >= closeRequest.minExchangeAmount,
            "EXCHANGE_SLIPPAGE_TOO_BIG"
        );

        uint256 repayAmount = details.loansTotalUSDValue.mul(settleResult.incomeTokenAmount).div(details.collateralsTotalUSDlValue);

        // TODO what to do if the result is negative?
        uint256 withdrawAmount = settleResult.incomeTokenAmount.sub(repayAmount);

        // TODO loan repay
        Pool.repay(state, account.loanIDs[0], repayAmount);

        CollateralAccounts.withdrawCollateral(
            state,
            closeRequest.accountID,
            state.allLoans[account.loanIDs[0]].assetID,
            withdrawAmount
        );

        // validateAccount(state, closeRequest.accountID);
    }
}