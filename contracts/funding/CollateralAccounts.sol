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
import "../lib/SafeMath.sol";
import "../lib/Consts.sol";
import "../funding/Auctions.sol";
import "../lib/Types.sol";

library CollateralAccounts {
    using SafeMath for uint256;

    /**
     * Get a user's default collateral account asset balance
     */
    function balanceOf(
        Store.State storage state,
        address user,
        uint16 marketID,
        address asset
    ) internal view returns (uint256) {
        Types.Wallet storage wallet = state.accounts[user][marketID].wallet;
        return wallet.balances[asset];
    }

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

        uint256 liquidateRate = state.markets[marketID].liquidateRate;

        uint256 baseUSDPrice = state.oracles[market.baseAsset].getPrice(market.baseAsset);
        uint256 quoteUSDPrice = state.oracles[market.quoteAsset].getPrice(market.quoteAsset);

        details.debtsTotalUSDValue = baseUSDPrice.mul(Pool._getPoolBorrow(state, market.baseAsset, user, marketID)).add(
            quoteUSDPrice.mul(Pool._getPoolBorrow(state, market.quoteAsset, user, marketID))
        );

        details.balancesTotalUSDValue = baseUSDPrice.mul(account.wallet.balances[market.baseAsset]).add(
            quoteUSDPrice.mul(account.wallet.balances[market.quoteAsset])
        );

        details.liquidable = details.balancesTotalUSDValue <
            details.debtsTotalUSDValue.mul(liquidateRate).div(Consts.LIQUIDATE_RATE_BASE());
    }

    /**
     * Liquidate multiple collateral account at once
     */
    function liquidateMulti(
        Store.State storage state,
        address[] memory users,
        uint16[] memory marketIDs
    )
        internal
    {
        for( uint256 i = 0; i < users.length; i++ ) {
            liquidate(state, users[i], marketIDs[i]);
        }
    }

    /**
     * Liquidate a collateral account
     */
    function liquidate(
        Store.State storage state,
        address user,
        uint16 marketID
    ) internal returns (bool) {
        Types.CollateralAccountDetails memory details = getDetails(state, user, marketID);

        if (!details.liquidable) {
            return false;
        }

        Types.Market storage market = state.markets[marketID];
        Types.CollateralAccount storage account = state.accounts[user][marketID];

        Pool.repay(state, user, marketID, market.baseAsset, account.wallet.balances[market.baseAsset]);
        Pool.repay(state, user, marketID, market.quoteAsset, account.wallet.balances[market.quoteAsset]);

        address collateralAsset;
        address debtAsset;

        if(account.wallet.balances[market.baseAsset] > 0) {
            // quote asset is debt, base asset is collateral
            collateralAsset = market.baseAsset;
            debtAsset = market.quoteAsset;
        } else {
            // base asset is debt, quote asset is collateral
            collateralAsset = market.quoteAsset;
            debtAsset = market.baseAsset;
        }

        Auctions.create(
            state,
            marketID,
            user,
            debtAsset,
            collateralAsset
        );

        account.status = Types.CollateralAccountStatus.Liquid;
        return true;
    }
}