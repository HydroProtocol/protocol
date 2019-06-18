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
import "./Modifiers.sol";

import "./exchange/Exchange.sol";
import "./exchange/Relayer.sol";

import "./funding/LendingPool.sol";
import "./funding/CollateralAccounts.sol";
import "./funding/BatchActions.sol";
import "./funding/Auctions.sol";

import "./lib/Transfer.sol";
import "./lib/Types.sol";

/**
 * External Functions
 */
contract ExternalFunctions is GlobalStore, Modifiers {

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

    ///////////////////////
    // Markets Functions //
    ///////////////////////

    function getAllMarketsCount()
        external
        view
        returns (uint256)
    {
        return state.marketsCount;
    }

    function getMarket(uint16 marketID)
        external
        view returns (Types.Market memory)
    {
        return state.markets[marketID];
    }

    function getPriceOracleOf(
        address asset
    )
        external
        view
        returns (address)
    {
        return address(state.oracles[asset]);
    }

    //////////////////////////////////
    // Collateral Account Functions //
    //////////////////////////////////

    function liquidateAccount(
        address user,
        uint16 marketID
    )
        external
        returns (bool, uint32)
    {
        return CollateralAccounts.liquidate(state, user, marketID);
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

    function getAuctionsCount()
        external
        view
        returns (uint32)
    {
        return state.auction.auctionsCount;
    }

    function getAuctionDetails(
        uint32 auctionID
    )
        external
        view
        returns (Types.AuctionDetails memory details)
    {
        return Auctions.getAuctionDetails(state, auctionID);
    }

    function fillAuctionWithAmount(
        uint32 auctionID,
        uint256 amount
    )
        external
    {
        return Auctions.fillAuctionWithAmount(state, auctionID, amount);
    }

    ///////////////////////////
    // LendingPool Functions //
    ///////////////////////////

    function getTotalBorrow(
        address asset
    )
        external
        view
        requireAssetExist(asset)
        returns (uint256)
    {
        return LendingPool.getTotalBorrow(state, asset);
    }

    function getTotalSupply(
        address asset
    )
        external
        view
        requireAssetExist(asset)
        returns (uint256)
    {
        return LendingPool.getTotalSupply(state, asset);
    }

    function getBorrowOf(
        address asset,
        address user,
        uint16 marketID
    )
        external
        view
        requireMarketIDAndAssetMatch(marketID, asset)
        returns (uint256)
    {
        return LendingPool.getBorrowOf(state, asset, user, marketID);
    }

    function getSupplyOf(
        address asset,
        address user
    )
        external
        view
        requireAssetExist(asset)
        returns (uint256)
    {
        return LendingPool.getSupplyOf(state, asset, user);
    }

    function getInterestRates(
        address asset,
        uint256 extraBorrowAmount
    )
        external
        view
        requireAssetExist(asset)
        returns (uint256 borrowInterestRate, uint256 supplyInterestRate)
    {
        return LendingPool.getInterestRates(state, asset, extraBorrowAmount);
    }

    function supply(
        address asset,
        uint256 amount
    )
        external
        requireAssetExist(asset)
    {
        LendingPool.supply(
            state,
            asset,
            amount,
            msg.sender
        );
    }

    function unsupply(
        address asset,
        uint256 amount
    )
        external
        requireAssetExist(asset)
    {
        LendingPool.withdraw(
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
        requireMarketIDAndAssetMatch(marketID, asset)
    {
        LendingPool.borrow(
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
        requireMarketIDAndAssetMatch(marketID, asset)
    {
        LendingPool.repay(
            state,
            msg.sender,
            marketID,
            asset,
            amount
        );
    }

    function getLendingPoolTokenAddress(
        address asset
    )
        external
        view
        requireAssetExist(asset)
        returns (address)
    {
        return state.pool.poolToken[asset];
    }

    /////////////////////////
    // Insurance Functions //
    /////////////////////////

    function getInsuranceBalance(
        address asset
    )
        external
        view
        requireAssetExist(asset)
        returns (uint256)
    {
        return state.pool.insuranceBalances[asset];
    }

    function closeAbortiveAuction(
        uint32 auctionID
    )
        external
    {
        Auctions.closeAbortiveAuction(state, auctionID);
    }

    ///////////////////////
    // Relayer Functions //
    ///////////////////////

    function approveDelegate(address delegate)
        external
    {
        Relayer.approveDelegate(state, delegate);
    }

    function revokeDelegate(address delegate)
        external
    {
        Relayer.revokeDelegate(state, delegate);
    }

    function joinIncentiveSystem()
        external
    {
        Relayer.joinIncentiveSystem(state);
    }

    function exitIncentiveSystem()
        external
    {
        Relayer.exitIncentiveSystem(state);
    }

    function canMatchOrdersFrom(address relayer)
        external
        view
        returns (bool)
    {
        return Relayer.canMatchOrdersFrom(state, relayer);
    }

    function isParticipant(address relayer)
        external
        view
        returns (bool)
    {
        return Relayer.isParticipant(state, relayer);
    }

    ////////////////////////
    // Balances Functions //
    ////////////////////////

    function deposit(address asset, uint256 amount)
        external
        payable
    {
        Transfer.depositFor(state, asset, msg.sender, BalancePath.getCommonPath(msg.sender), amount);
    }

    function withdraw(address asset, uint256 amount)
        external
    {
        Transfer.withdrawFrom(state, asset, BalancePath.getCommonPath(msg.sender), msg.sender, amount);
    }

    function transfer(
        address asset,
        Types.BalancePath calldata fromBalancePath,
        Types.BalancePath calldata toBalancePath,
        uint256 amount
    )
        external
    {
        require(fromBalancePath.user == msg.sender, "CAN_NOT_MOVE_OTHERS_ASSET");
        require(toBalancePath.user == msg.sender, "CAN_NOT_MOVE_ASSET_TO_OTHER"); // should we allow to transfer to other ??

        Transfer.transferFrom(state, asset, fromBalancePath, toBalancePath, amount);
    }

    function balanceOf(
        address asset,
        address user
    )
        external
        view
        returns (uint256)
    {
        return Transfer.balanceOf(state,  BalancePath.getCommonPath(user), asset);
    }

    function marketBalanceOf(
        uint16 marketID,
        address asset,
        address user
    )
        external
        view
        returns (uint256)
    {
        return Transfer.balanceOf(state,  BalancePath.getMarketPath(user, marketID), asset);
    }

    function getMarketTransferableAmount(
        uint16 marketID,
        address asset,
        address user
    )
        external
        view
        returns (uint256)
    {
        return CollateralAccounts.getTransferableAmount(state, marketID, user, asset);
    }

    /** fallback function to allow deposit ether into this contract */
    function ()
        external
        payable
    {
        // deposit ${msg.value} ether for ${msg.sender}
        Transfer.depositFor(state, Consts.ETHEREUM_TOKEN_ADDRESS(), msg.sender, BalancePath.getCommonPath(msg.sender), msg.value);
    }

    ////////////////////////
    // Exchange Functions //
    ////////////////////////

    function cancelOrder(
        Types.Order calldata order
    )
        external
    {
        Exchange.cancelOrder(state, order);
    }

    function isOrderCancelled(
        bytes32 orderHash
    )
        external
        view
        returns(bool)
    {
        return state.exchange.cancelled[orderHash];
    }

    function matchOrders(
        Types.MatchParams memory params
    )
        public
    {
        Exchange.matchOrders(state, params);
    }

    function getDiscountedRate(
        address user
    )
        external
        view
        returns (uint256)
    {
        return Discount.getDiscountedRate(state, user);
    }

    function getHydroTokenAddress()
        external
        view
        returns (address)
    {
        return state.exchange.hotTokenAddress;
    }

    function getOrderFilledAmount(
        bytes32 orderHash
    )
        external
        view
        returns (uint256)
    {
        return state.exchange.filled[orderHash];
    }
}