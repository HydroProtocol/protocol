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
import "../lib/Types.sol";
import "../lib/ExternalCaller.sol";
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

        address baseAsset = market.baseAsset;
        address quoteAsset = market.quoteAsset;

        uint256 baseUSDPrice = ExternalCaller.getAssetPriceFromPriceOracle(
            address(state.assets[baseAsset].priceOracle),
            baseAsset
        );
        uint256 quoteUSDPrice = ExternalCaller.getAssetPriceFromPriceOracle(
            address(state.assets[quoteAsset].priceOracle),
            quoteAsset
        );

        uint256 baseBorrowOf = LendingPool.getBorrowOf(state, baseAsset, user, marketID);
        uint256 quoteBorrowOf = LendingPool.getBorrowOf(state, quoteAsset, user, marketID);

        details.debtsTotalUSDValue = SafeMath.add(
            baseBorrowOf.mul(baseUSDPrice),
            quoteBorrowOf.mul(quoteUSDPrice)
        ) / Consts.ORACLE_PRICE_BASE();

        details.balancesTotalUSDValue = SafeMath.add(
            account.balances[baseAsset].mul(baseUSDPrice),
            account.balances[quoteAsset].mul(quoteUSDPrice)
        ) / Consts.ORACLE_PRICE_BASE();

        if (details.status == Types.CollateralAccountStatus.Normal) {
            details.liquidatable = details.balancesTotalUSDValue < Decimal.mulCeil(details.debtsTotalUSDValue, market.liquidateRate);
        } else {
            details.liquidatable = false;
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

        // liquidating or liquidatable account can't move asset
        if (details.status == Types.CollateralAccountStatus.Liquid || details.liquidatable) {
            return 0;
        }

        uint256 assetBalance = state.accounts[user][marketID].balances[asset];

        // no debt, can move all assets out
        if (details.debtsTotalUSDValue == 0) {
            return assetBalance;
        }

        if (assetBalance == 0) {
            return 0;
        }

        // If and only if balance USD value is larger than transferableUSDValueBar, the user is able to withdraw some assets
        uint256 transferableUSDValueBar = Decimal.mulFloor(
            details.debtsTotalUSDValue,
            state.markets[marketID].withdrawRate
        );

        if(transferableUSDValueBar > details.balancesTotalUSDValue) {
            return 0;
        }

        uint256 assetUSDPrice = state.assets[asset].priceOracle.getPrice(asset);

        // round down
        uint256 transferableAmount = SafeMath.mul(
            details.balancesTotalUSDValue - transferableUSDValueBar,
            Consts.ORACLE_PRICE_BASE()
        ).div(assetUSDPrice);

        if (transferableAmount > assetBalance) {
            return assetBalance;
        }

        return transferableAmount;
    }
}