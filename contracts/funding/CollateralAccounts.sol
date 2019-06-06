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
import "../lib/params.sol";
import "../lib/SafeMath.sol";
import "../lib/Consts.sol";
import "../funding/Auctions.sol";

import { Types, Asset } from "../lib/Types.sol";

library CollateralAccounts {
    using SafeMath for uint256;
    using Asset for Types.Asset;

    // deposit collateral for default account
    function depositCollateral(
        Store.State storage state,
        uint32 accountID,
        uint16 assetID,
        uint256 amount
    )
        internal
    {
        if (amount == 0) {
            return;
        }

        Types.CollateralAccount storage account = state.allCollateralAccounts[accountID];
        state.balances[account.owner][assetID] = state.balances[account.owner][assetID].sub(amount);

        account.collateralAssetAmounts[assetID] = account.collateralAssetAmounts[assetID].add(amount);
        Events.logDepositCollateral(assetID, account.owner, amount);
    }

    function withdrawCollateral(
        Store.State storage state,
        uint32 accountID,
        uint16 assetID,
        uint256 amount
    )
        internal
    {
        if (amount == 0) {
            return;
        }

        Types.CollateralAccount storage account = state.allCollateralAccounts[accountID];
        account.collateralAssetAmounts[assetID] = account.collateralAssetAmounts[assetID].sub(amount);
        state.balances[account.owner][assetID] = state.balances[account.owner][assetID].add(amount);

        Events.logDepositWithdraw(assetID, account.owner, amount);
    }


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
        uint32 marketID
    )
        internal view
        returns (Types.CollateralAccountDetails memory details)
    {
        Types.CollateralAccount storage account = state.accounts[user][marketID];
        uint256 liquidateRate = state.markets[marketID].liquidateRate;

        // TODO use real value
        details.debtsTotalUSDValue = 0;
        details.balancesTotalUSDValue = 0;

        details.liquidable = details.balancesTotalUSDValue <
            details.debtsTotalUSDValue.mul(liquidateRate).div(Consts.LIQUIDATE_RATE_BASE());
    }

    /**
     * Liquidate multiple collateral account at once
     */
    function liquidateMulti(
        Store.State storage state,
        address[] memory users,
        uint32[] memory marketIDs
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
        uint32 marketID
    ) internal returns (bool) {
        Types.CollateralAccount storage account = state.allCollateralAccounts[id];
        Types.CollateralAccountDetails memory details = getDetails(state, user, marketID);

        if (!details.liquidable) {
            return false;
        }

        // storage changes
        for (uint256 i = 0; i < details.loans.length; i++ ) {
            Auctions.createAuction(
                state,
                details.loans[i].id,
                account.owner,
                details.loans[i].amount,
                details.loanValues[i],
                details.loansTotalUSDValue,
                details.collateralAssetAmounts
            );

            Auctions.removeLoanIDFromCollateralAccount(state, details.loans[i].id, id);
        }

        // confiscate all collaterals
        for (uint16 i = 0; i < state.assetsCount; i++) {
            account.collateralAssetAmounts[i] = 0;
        }

        account.status = Types.CollateralAccountStatus.Liquid;

        return true;
    }
}