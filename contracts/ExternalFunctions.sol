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

import "./lib/Transfer.sol";
import "./lib/Relayer.sol";

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

    function getAsset(uint16 assetID)
        external
        view
        returns (Types.Asset memory)
    {
        return Assets.getAsset(state, assetID);
    }

    function getAssetIDByAddress(address tokenAddress)
        external
        view
        returns (uint16)
    {
        return Assets.getAssetIDByAddress(state, tokenAddress);
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

    function getCollateralAccountDetails(
        uint256 accountID
    )
        external
        view
        returns (Types.CollateralAccountDetails memory)
    {
        return CollateralAccounts.getCollateralAccountDetails(state, accountID);
    }

    function depositDefaultCollateral(
        uint16 assetID,
        uint256 amount
    )
        external
    {
        CollateralAccounts.depositDefaultCollateral(state, assetID, msg.sender, amount);
    }

    ////////////////////
    // Pool Functions //
    ////////////////////

    function poolSupply(
        uint16 assetID,
        uint256 amount
    )
        external
    {
        Pool.supply(state, assetID, amount);
    }

    ///////////////////////
    // Relayer Functions //
    ///////////////////////

    function approveDelegate(address delegate) external {
        Relayer.approveDelegate(state, delegate);
    }

    function revokeDelegate(address delegate) external {
        Relayer.revokeDelegate(state, delegate);
    }

    function joinIncentiveSystem() external {
        Relayer.joinIncentiveSystem(state);
    }

    function exitIncentiveSystem() external {
        Relayer.exitIncentiveSystem(state);
    }

    function canMatchOrdersFrom(address relayer) external view returns (bool) {
        return Relayer.canMatchOrdersFrom(state, relayer);
    }

    function isParticipant(address relayer) external view returns (bool) {
        return Relayer.isParticipant(state, relayer);
    }


    ////////////////////////
    // Transfer Functions //
    ////////////////////////

    function deposit(uint16 assetID, uint256 amount) external payable {
        Transfer.deposit(state, assetID, amount);
    }

    function withdraw(uint16 assetID, uint256 amount) external {
        Transfer.withdraw(state, assetID, amount);
    }

    function balanceOf(uint16 assetID, address user) external view returns (uint256) {
        return Transfer.balanceOf(state, assetID, user);
    }

    /** @dev fallback function to allow deposit ether into this contract */
    function () external payable {
        // deposit ${msg.value} ether for ${msg.sender}
        Transfer.deposit(state, Assets.getAssetIDByAddress(state, Consts.ETHEREUM_TOKEN_ADDRESS()), msg.value);
    }
}