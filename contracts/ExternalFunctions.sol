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

import "./funding/Assets.sol";
import "./funding/Pool.sol";
import "./funding/CollateralAccounts.sol";
import "./GlobalStore.sol";

/**
 * External Functions
 */
contract ExternalFunctions is GlobalStore {

    //////////////////////
    // Assets Functions //
    //////////////////////

    function getAllAssetsCount()
        external
        view
        returns (uint256)
    {
        return Assets.getAllAssetsCount(state);
    }

    function getAssetID(address tokenAddress)
        external
        view returns (uint16 assetID)
    {
        return Assets.getAssetIDByAddress(state, tokenAddress);
    }

    function getAssetInfo(uint16 assetID)
        external
        view returns (address tokenAddress, address oracleAddress, uint256 collateralRate)
    {
        Types.Asset storage asset = state.assets[assetID];
        oracleAddress = address(asset.oracle);
        return (asset.tokenAddress, address(asset.oracle), asset.collateralRate);
    }

    //////////////////////////////////
    // Collateral Account Functions //
    //////////////////////////////////

    function liquidateCollateralAccounts(uint256[] calldata accountIDs)
        external
    {
        CollateralAccounts.liquidateCollateralAccounts(state, accountIDs);
    }

    function liquidateCollateralAccount(uint256 accountID)
        external
    {
        CollateralAccounts.liquidateCollateralAccount(state, accountID);
    }

    function isCollateralAccountLiquidable(
        uint256 accountID
    )
        external
        view
        returns (bool)
    {
        return CollateralAccounts.isCollateralAccountLiquidable(state, accountID);
    }

    function getUserDefaultAccount(
        address user
    )
        external
        view
        returns (uint32)
    {
        return uint32(state.userDefaultCollateralAccounts[user]);
    }

    function getCollateralAccountDetails(
        uint256 accountID
    )
        external
        view
        returns (Types.CollateralAccountDetails memory)
    {
        return CollateralAccounts.getCollateralAccountDetails(state, accountID);
    }

    function depositCollateral(
        uint16 assetID,
        uint256 amount
    )
        external
    {
        CollateralAccounts.depositCollateral(state, assetID, msg.sender, amount);
    }

    ////////////////////
    // Loan Functions //
    ////////////////////

    function repayLoan(
        uint32 loanID,
        uint256 amount
    )
        external
    {

    }

    ////////////////////
    // Pool Functions //
    ////////////////////

    function getPoolTotalSupply(
        uint16 assetID
    )
        external
        view
        returns(uint256)
    {
        return Pool._getSupplyWithInterest(state, assetID);
    }

    function getPoolTotalBorrow(
        uint16 assetID
    )
        external
        view
        returns(uint256)
    {
        return state.pool.totalBorrow[assetID];
    }

    function getPoolTotalShares(
        uint16 assetID
    )
        external
        view
        returns(uint256)
    {
        return state.pool.totalSupplyShares[assetID];
    }

    function getPoolSharesOf(
        uint16 assetID,
        address user
    )
        external
        view
        returns(uint256)
    {
        return state.pool.supplyShares[assetID][user];
    }

    function getPoolAnnualInterest(
        uint16 assetID
    )
        external
        view
        returns(uint256)
    {
        return state.pool.poolAnnualInterest[assetID];
    }

    function getPoolInterestStartTime(
        uint16 assetID
    )
        external
        view
        returns(uint40)
    {
        return state.pool.poolInterestStartTime[assetID];
    }

    function poolSupply(
        uint16 assetID,
        uint256 amount
    )
        external
    {
        Pool.supply(state, assetID, amount);
    }

    function borrowFromPool(
        uint32 collateralAccountId,
        uint16 assetID,
        uint256 amount,
        uint16 maxInterestRate,
        uint40 minExpiredAt
    )
        external
        returns(uint32 loanId)
    {
        require(state.collateralAccountCount > collateralAccountId, "COLLATERAL_ACCOUNT_NOT_EXIST");
        loanId = Pool.borrowFromPoolInternal(
            state,
            collateralAccountId,
            assetID,
            amount,
            maxInterestRate,
            minExpiredAt
        );
        require(!CollateralAccounts.isCollateralAccountLiquidable(state, collateralAccountId), "COLLATERAL_NOT_ENOUGH");
        return loanId;
    }
}