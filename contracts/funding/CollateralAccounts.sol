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

        uint256 baseBorrowOf = LendingPool.getAmountBorrowed(state, baseAsset, user, marketID);
        uint256 quoteBorrowOf = LendingPool.getAmountBorrowed(state, quoteAsset, user, marketID);

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

    /**
     * The amount that is avaliable to transfer out of the collateral account.
     * If there are no open loans, this is just the total asset balance.
     * If there is are open loans, then this is the maximum amount that can be withdrawn
     * without falling below the minimum collateral ratio
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
        uint256 transferableThresholdUSDValue = Decimal.mulFloor(
            details.debtsTotalUSDValue,
            state.markets[marketID].withdrawRate
        );

        if(transferableThresholdUSDValue > details.balancesTotalUSDValue) {
            return 0;
        }

        uint256 assetUSDPrice = state.assets[asset].priceOracle.getPrice(asset);

        // round down
        uint256 transferableAmount = SafeMath.mul(
            details.balancesTotalUSDValue - transferableThresholdUSDValue,
            Consts.ORACLE_PRICE_BASE()
        ).div(assetUSDPrice);

        if (transferableAmount > assetBalance) {
            return assetBalance;
        }

        return transferableAmount;
    }
<<<<<<< HEAD

    /**
     * Liquidate a collateral account, potentially resulting in the start of a new auction
     */
    function liquidate(
        Store.State storage state,
        address user,
        uint16 marketID
    )
        internal
        returns (bool, uint32)
    {

        // check the position is eligble for liquidation (does not meet collateral requirements)
        Types.CollateralAccountDetails memory details = getDetails(
            state,
            user,
            marketID
        );

        require(details.liquidatable, "ACCOUNT_NOT_LIQUIDABLE");

        // first repay the debts out of the collateral directly
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

        uint256 remainingBaseAssetDebt = LendingPool.getAmountBorrowed(
            state,
            market.baseAsset,
            user,
            marketID
        );

        uint256 remainingQuoteAssetDebt = LendingPool.getAmountBorrowed(
            state,
            market.quoteAsset,
            user,
            marketID
        );

        if (remainingBaseAssetDebt == 0 && remainingQuoteAssetDebt == 0) {
            // Because liquidation rate for Type.liquidatable==true is typically greater than 1,
            // there are edge cases where calling liquidate does not result in an auction.
            // So it just ends here and return auctionId = 0
            return (false, 0);
        }

        // start a auction to pay back remaining debt
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
=======
>>>>>>> 96b7f71315e2d52fc5d229489bf5ac66a98773ae
}