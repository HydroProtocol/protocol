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
import "../lib/Types.sol";
import "../lib/AssemblyCall.sol";

import "./LendingPool.sol";

/**
 * Library to get infomation of collateral accounts.
 */
library CollateralAccounts {
    using SafeMath for uint256;

    function getDetails(
        Store.State storage state,
        address user,
        uint16 marketID
    )
        internal
        view
        returns (Types.CollateralAccountDetails memory details)
    {
        Types.CollateralAccount storage account = state.accounts[user][marketID];
        Types.Market storage market = state.markets[marketID];

        details.status = account.status;

        address baseAsset = market.baseAsset;
        address quoteAsset = market.quoteAsset;

        uint256 baseUSDPrice = AssemblyCall.getAssetPriceFromPriceOracle(
            address(state.assets[baseAsset].priceOracle),
            baseAsset
        );
        uint256 quoteUSDPrice = AssemblyCall.getAssetPriceFromPriceOracle(
            address(state.assets[quoteAsset].priceOracle),
            quoteAsset
        );

        uint256 baseBorrowOf = LendingPool.getAmountBorrowed(state, baseAsset, user, marketID);
        uint256 quoteBorrowOf = LendingPool.getAmountBorrowed(state, quoteAsset, user, marketID);

        details.debtsTotalUSDValue = SafeMath.add(
            baseBorrowOf.mul(baseUSDPrice),
            quoteBorrowOf.mul(quoteUSDPrice)
        ) / Decimal.one();

        details.balancesTotalUSDValue = SafeMath.add(
            account.balances[baseAsset].mul(baseUSDPrice),
            account.balances[quoteAsset].mul(quoteUSDPrice)
        ) / Decimal.one();

        if (details.status == Types.CollateralAccountStatus.Normal) {
            details.liquidatable = details.balancesTotalUSDValue < Decimal.mulCeil(details.debtsTotalUSDValue, market.liquidateRate);
        } else {
            details.liquidatable = false;
        }
    }

    /**
     * Get the amount that is avaliable to transfer out of the collateral account.
     *
     * If there are no open loans, this is just the total asset balance.
     *
     * If there are open loans, then this is the maximum amount that can be withdrawn
     *   without falling below the withdraw collateral ratio
     */
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

        // already checked at batch operation
        // liquidating or liquidatable account can't move asset

        uint256 assetBalance = state.accounts[user][marketID].balances[asset];

        // If and only if balance USD value is larger than transferableUSDValueBar, the user is able to withdraw some assets
        uint256 transferableThresholdUSDValue = Decimal.mulCeil(
            details.debtsTotalUSDValue,
            state.markets[marketID].withdrawRate
        );

        if(transferableThresholdUSDValue > details.balancesTotalUSDValue) {
            return 0;
        } else {
            uint256 transferableUSD = details.balancesTotalUSDValue - transferableThresholdUSDValue;
            uint256 assetUSDPrice = state.assets[asset].priceOracle.getPrice(asset);
            uint256 transferableAmount = Decimal.divFloor(transferableUSD, assetUSDPrice);
            if (transferableAmount > assetBalance) {
                return assetBalance;
            } else {
                return transferableAmount;
            }
        }
    }
}