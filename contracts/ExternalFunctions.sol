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

import "./exchange/Exchange.sol";

import "./funding/Assets.sol";
import "./funding/Pool.sol";
import "./funding/Margin.sol";
import "./funding/CollateralAccounts.sol";
import "./GlobalStore.sol";

import "./lib/Transfer.sol";
import "./lib/Relayer.sol";

/**
 * External Functions
 */
contract ExternalFunctions is GlobalStore {

    ///////////////
    // Signature //
    ///////////////

    function isValidSignature(bytes32 hash, address signerAddress, Types.Signature calldata signature) external pure returns (bool) {
        return Signature.isValidSignature(hash, signerAddress, signature);
    }

    ////////////
    // EIP712 //
    ////////////

    function DOMAIN_SEPARATOR() external pure returns (bytes32) {
        return EIP712.DOMAIN_SEPARATOR();
    }

    // function DOMAIN_SEPARATOR() external view returns (bytes) {
    //     return EIP712.DOMAIN_SEPARATOR
    // }

    // function EIP712_ORDER_TYPE() external view returns (bytes) {
    //     return EIP712.EIP712_ORDER_TYPE
    // }

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

    function getCollateralAccountsCount()
        external
        view
        returns (uint256)
    {
        return state.collateralAccountCount;
    }

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

    function depositDefaultCollateral(
        uint16 assetID,
        uint256 amount
    )
        external
    {
        CollateralAccounts.depositDefaultCollateral(state, assetID, msg.sender, amount);
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
        return state.pool.totalSupply[assetID];
        // return Pool._getSupplyWithInterest(state, assetID);
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

    function poolWithdraw(
        uint16 assetID,
        uint256 sharesAmount
    )
        external
    {
        Pool.withdraw(state, assetID, amount);
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

        loanId = Pool.borrow(
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

    //////////////
    // Exchange //
    //////////////

    function cancelOrder(Types.ExchangeOrder calldata order) external {
        Exchange.cancelOrder(state, order);
    }

    function isOrderCancelled(bytes32 orderHash) external view returns(bool) {
        return state.exchange.cancelled[orderHash];
    }

    function exchangeMatchOrders(Types.ExchangeMatchParams memory params) public {
        Exchange.exchangeMatchOrders(state, params, state.balances[params.takerOrderParam.trader]);
    }

    function getDiscountedRate(address user) external view returns (uint256) {
        return Discount.getDiscountedRate(state, user);
    }

    function getHydroTokenAddress() external view returns (address) {
        return state.hotTokenAddress;
    }

    function getExchangeOrderFilledAmount(bytes32 orderHash) external view returns (uint256) {
        return state.exchange.filled[orderHash];
    }

    ////////////
    // Margin //
    ////////////

    function openMargin(Margin.OpenMarginRequest memory openRequest, Types.ExchangeMatchParams memory params) public {
        Margin.open(state, openRequest, params);
    }
}