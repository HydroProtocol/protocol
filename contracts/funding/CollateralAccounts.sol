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
import "../lib/Decimal.sol";
import "../lib/SafeMath.sol";
import "../lib/Consts.sol";
import "../funding/Auctions.sol";
import "../lib/Types.sol";
import "./LendingPool.sol";

library CollateralAccounts {
    using SafeMath for uint256;

    function getDetails(
        Store.State storage state,
        address user,
        uint16 marketID
    )
        internal view
        returns (Types.CollateralAccountDetails memory details)
    {
        Types.CollateralAccount storage account = state.accounts[user][marketID];
        Types.Market storage market = state.markets[marketID];
        details.status = account.status;

        uint256 baseUSDPrice = state.oracles[market.baseAsset].getPrice(market.baseAsset);
        uint256 quoteUSDPrice = state.oracles[market.quoteAsset].getPrice(market.quoteAsset);

        details.debtsTotalUSDValue = baseUSDPrice.mul(LendingPool.getBorrowOf(state, market.baseAsset, user, marketID)).add(
            quoteUSDPrice.mul(LendingPool.getBorrowOf(state, market.quoteAsset, user, marketID))
        ).div(Consts.ORACLE_PRICE_BASE());

        details.balancesTotalUSDValue = baseUSDPrice.mul(account.balances[market.baseAsset]).add(
            quoteUSDPrice.mul(account.balances[market.quoteAsset])
        ).div(Consts.ORACLE_PRICE_BASE());

        if (account.status == Types.CollateralAccountStatus.Normal) {
            details.liquidable = details.balancesTotalUSDValue <
                Decimal.mul(details.debtsTotalUSDValue, state.markets[marketID].liquidateRate);
        } else {
            details.liquidable = false;
        }
    }

    function getTransferableAmount(
        Store.State storage state,
        uint16 marketID,
        address user,
        address asset
    )
        internal
        view
        returns (uint256)
    {
        Types.CollateralAccountDetails memory details = getDetails(state, user, marketID);

        // liquidating or liquidable account can't move asset
        if (details.status == Types.CollateralAccountStatus.Liquid || details.liquidable) {
            return 0;
        }

        // no debt, can move all assets out
        if (details.debtsTotalUSDValue == 0) {
            return state.accounts[user][marketID].balances[asset];
        }

        // If and only if balance USD value is larger than transferableUSDValueBar, the user is able to withdraw some assets
        uint256 transferableUSDValueBar = Decimal.mul(
            details.debtsTotalUSDValue,
            state.markets[marketID].withdrawRate
        );

        if(transferableUSDValueBar > details.balancesTotalUSDValue) {
            return 0;
        }

        uint256 asserUSDPrice = state.oracles[asset].getPrice(asset);

        // round down
        return (details.balancesTotalUSDValue - transferableUSDValueBar).mul(Consts.ORACLE_PRICE_BASE()).div(asserUSDPrice);
    }

    /**
     * Liquidate a collateral account
     */
    function liquidate(
        Store.State storage state,
        address user,
        uint16 marketID
    )
        internal
        returns (bool, uint32)
    {
        Types.CollateralAccountDetails memory details = getDetails(
            state,
            user,
            marketID
        );

        require(details.liquidable, "ACCOUNT_NOT_LIQUIDABLE");

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

        uint256 leftBaseAssetDebt = LendingPool.getBorrowOf(
            state,
            market.baseAsset,
            user,
            marketID
        );

        uint256 leftQuoteAssetDebt = LendingPool.getBorrowOf(
            state,
            market.quoteAsset,
            user,
            marketID
        );

        if (leftBaseAssetDebt == 0 && leftQuoteAssetDebt == 0) {
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

        uint32 newAuctionID = Auctions.create(
            state,
            marketID,
            user,
            msg.sender,
            debtAsset,
            collateralAsset
        );

        return (true, newAuctionID);
    }
}