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

import "./GlobalStore.sol";

import "./exchange/Exchange.sol";
import "./exchange/Relayer.sol";

import "./funding/Markets.sol";
import "./funding/Pool.sol";
import "./funding/CollateralAccounts.sol";
import "./funding/BatchActions.sol";

import "./lib/Transfer.sol";

/**
 * External Functions
 */
contract ExternalFunctions is GlobalStore {

    ////////////////////////////
    // Batch Actions Function //
    ////////////////////////////

    function batch(
        BatchActions.Action[] memory actions
    )
        public
        payable
    {
        BatchActions.batch(state, actions);
    }

    ////////////////////////
    // Signature Function //
    ////////////////////////

    function isValidSignature(
        bytes32 hash,
        address signerAddress,
        Types.Signature calldata signature
    )
        external
        pure
        returns (bool)
    {
        return Signature.isValidSignature(hash, signerAddress, signature);
    }

    function DOMAIN_SEPARATOR() external pure returns (bytes32) {
        return EIP712.DOMAIN_SEPARATOR();
    }

    ///////////////////////
    // Markets Functions //
    ///////////////////////

    function getAllMarketsCount()
        external
        view
        returns (uint256)
    {
        return Markets.getAllMarketsCount(state);
    }

    function getMarket(uint16 marketID)
        external
        view returns (Types.Market memory)
    {
        return state.markets[marketID];
    }

    //////////////////////////////////
    // Collateral Account Functions //
    //////////////////////////////////

    function liquidateAccounts(
        address[] calldata users,
        uint16[] calldata marketIDs
    )
        external
    {
        CollateralAccounts.liquidateMulti(state, users, marketIDs);
    }

    function liquidateAccount(
        address user,
        uint16 marketID
    )
        external
    {
        CollateralAccounts.liquidate(state, user, marketID);
    }

    function isAccountLiquidable(
        address user,
        uint16 marketID
    )
        external
        view
        returns (bool)
    {
        return CollateralAccounts.getDetails(state, user, marketID).liquidable;
    }

    function getAccountDetails(
        address user,
        uint16 marketID
    )
        external
        view
        returns (Types.CollateralAccountDetails memory details)
    {
        return CollateralAccounts.getDetails(state, user, marketID);
    }

    ////////////////////
    // Pool Functions //
    ////////////////////

    function getPoolTotalBorrow(
        address asset
    )
        external
        view
        returns (uint256)
    {
        return Pool._getPoolTotalBorrow(state, asset);
    }

    function getPoolTotalSupply(
        address asset
    )
        external
        view
        returns (uint256)
    {
        return Pool._getPoolTotalSupply(state, asset);
    }

    function getPoolTotalBorrowOf(
        address asset,
        address user,
        uint16 marketID
    )
        external
        view
        returns (uint256)
    {
        return Pool._getPoolBorrow(state, asset, user, marketID);
    }

    function getPoolTotalSupplyOf(
        address asset,
        address user
    )
        external
        view
        returns (uint256)
    {
        return Pool._getPoolSupply(state, asset, user);
    }

    function getPoolInterestRate(
        address asset,
        uint256 extraBorrowAmount
    )
        external
        view
        returns (uint256 borrowInterestRate, uint256 supplyInterestRate)
    {
        return Pool._getInterestRate(state, asset, extraBorrowAmount);
    }

    function supplyPool(
        address asset,uint256 amount
    )
        external
    {
        Pool.supply(
            state,
            asset,
            amount,
            msg.sender
        );
    }

    function withdrawPool(
        address asset,
        uint256 amount
    )
        external
    {
        Pool.withdraw(
            state,
            asset,
            amount,
            msg.sender
        );
    }

    function borrow(
        address asset,
        uint256 amount,
        uint16 marketID
    )
        external
    {
        Pool.borrow(
            state,
            msg.sender,
            marketID,
            asset,
            amount
        );

    }

    function repay(
        address asset,
        uint256 amount,
        uint16 marketID
    )
        external
    {
        Pool.repay(
            state,
            msg.sender,
            marketID,
            asset,
            amount
        );
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
    // Balances Functions //
    ////////////////////////

    function deposit(address asset, uint256 amount) external payable {
        Transfer.depositFor(state, asset, msg.sender, WalletPath.getBalancePath(msg.sender), amount);
    }

    function withdraw(address asset, uint256 amount) external {
        Transfer.withdrawFrom(state, asset, WalletPath.getBalancePath(msg.sender), msg.sender, amount);
    }

    function balanceOf(address asset, address user) external view returns (uint256) {
        return Transfer.balanceOf(state,  WalletPath.getBalancePath(user), asset);
    }

    function marketBalanceOf(uint16 marketID, address asset, address user) external view returns (uint256) {
        return Transfer.balanceOf(state,  WalletPath.getMarketPath(user, marketID), asset);
    }

    /** fallback function to allow deposit ether into this contract */
    function () external payable {
        // deposit ${msg.value} ether for ${msg.sender}
        Transfer.depositFor(state, Consts.ETHEREUM_TOKEN_ADDRESS(), msg.sender, WalletPath.getBalancePath(msg.sender), msg.value);
    }

    ////////////////////////
    // Exchange Functions //
    ////////////////////////

    function cancelOrder(Types.Order calldata order) external {
        Exchange.cancelOrder(state, order);
    }

    function isOrderCancelled(bytes32 orderHash) external view returns(bool) {
        return state.exchange.cancelled[orderHash];
    }

    function matchOrders(Types.MatchParams memory params) public {
        Exchange.matchOrders(state, params);
    }

    function getDiscountedRate(address user) external view returns (uint256) {
        return Discount.getDiscountedRate(state, user);
    }

    function getHydroTokenAddress() external view returns (address) {
        return state.hotTokenAddress;
    }

    function getOrderFilledAmount(bytes32 orderHash) external view returns (uint256) {
        return state.exchange.filled[orderHash];
    }
}