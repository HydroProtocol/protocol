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
import "../funding/Loans.sol";
import "../funding/Auctions.sol";

import { Types, Loan, Asset } from "../lib/Types.sol";

library CollateralAccounts {
    using SafeMath for uint256;
    using Loan for Types.Loan;
    using Asset for Types.Asset;

    function findOrCreateDefaultCollateralAccount(
        Store.State storage state,
        address user
    ) internal returns (Types.CollateralAccount storage) {
        uint256 id = state.userDefaultCollateralAccounts[user];
        Types.CollateralAccount storage account = state.allCollateralAccounts[id];

        if (account.owner != user) {
            // default account liquidate rate is 150%
            id = createCollateralAccount(state, user, 150);
            state.userDefaultCollateralAccounts[user] = id;
            account = state.allCollateralAccounts[id];
        }

        return account;
    }

    function createCollateralAccount(
        Store.State storage state,
        address user,
        uint16 liquidateRate
    ) internal returns (uint32) {
        uint32 id = state.collateralAccountCount++;
        Types.CollateralAccount memory account;

        account.id = id;
        account.liquidateRate = liquidateRate;
        account.owner = user;

        state.allCollateralAccounts[id] = account;
        return id;
    }

    // deposit collateral for default account
    function depositDefaultCollateral(
        Store.State storage state,
        uint16 assetID,
        address user,
        uint256 amount
    )
        internal
    {
        if (amount == 0) {
            return;
        }

        state.balances[user][assetID] = state.balances[user][assetID].sub(amount);
        Types.CollateralAccount storage account = findOrCreateDefaultCollateralAccount(state, user);

        account.collateralAssetAmounts[assetID] = account.collateralAssetAmounts[assetID].add(amount);
        Events.logDepositCollateral(assetID, user, amount);
    }

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



    /**
     * Get a user's default collateral account asset balance
     */
    function collateralBalanceOf(
        Store.State storage state,
        uint16 assetID,
        address user
    ) internal view returns (uint256) {
        uint256 id = state.userDefaultCollateralAccounts[user];
        Types.CollateralAccount storage account = state.allCollateralAccounts[id];

        if (account.owner != user) {
            return 0;
        }

        return account.collateralAssetAmounts[assetID];
    }

    function getCollateralAccountDetails(
        Store.State storage state,
        uint256 id
    )
        internal view
        returns (Types.CollateralAccountDetails memory details)
    {
        Types.CollateralAccount storage account = state.allCollateralAccounts[id];
        details.collateralAssetAmounts = new uint256[](state.assetsCount);

        for (uint16 i = 0; i < state.assetsCount; i++) {
            Types.Asset storage asset = state.assets[i];

            uint256 amount = account.collateralAssetAmounts[i];

            details.collateralAssetAmounts[i] = amount;
            details.collateralsTotalUSDlValue = details.collateralsTotalUSDlValue.add(
                asset.getPrice().mul(amount).div(Consts.ORACLE_PRICE_BASE())
            );
        }

        details.loans = Loans.getByIDs(state, account.loanIDs);

        if (details.loans.length <= 0) {
            return details;
        }

        details.loanValues = new uint256[](details.loans.length);

        for (uint256 i = 0; i < details.loans.length; i++) {

            uint256 totalInterest = details.loans[i].
                interest(details.loans[i].amount, uint40(block.timestamp)).
                div(Consts.INTEREST_RATE_BASE().mul(Consts.SECONDS_OF_YEAR()));

            Types.Asset storage asset = state.assets[details.loans[i].assetID];

            details.loanValues[i] = asset.getPrice().mul(details.loans[i].amount.add(totalInterest)).div(Consts.ORACLE_PRICE_BASE());
            details.loansTotalUSDValue = details.loansTotalUSDValue.add(details.loanValues[i]);
        }

        details.liquidable = details.collateralsTotalUSDlValue <
            details.loansTotalUSDValue.mul(account.liquidateRate).div(Consts.LIQUIDATE_RATE_BASE());
    }

    function liquidateCollateralAccounts(
        Store.State storage state,
        uint256[] memory accountIDs
    ) internal {
        for( uint256 i = 0; i < accountIDs.length; i++ ) {
            liquidateCollateralAccount(state, accountIDs[i]);
        }
    }

    function isCollateralAccountLiquidable(
        Store.State storage state,
        uint256 id
    ) internal view returns (bool) {
        Types.CollateralAccountDetails memory details = getCollateralAccountDetails(state, id);
        return details.liquidable;
    }

    /**
     * Total liquidate a collateral account
     */
    function liquidateCollateralAccount(
        Store.State storage state,
        uint256 id
    ) internal returns (bool) {
        Types.CollateralAccount storage account = state.allCollateralAccounts[id];
        Types.CollateralAccountDetails memory details = getCollateralAccountDetails(state, id);

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