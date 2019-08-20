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

import "./funding/LendingPool.sol";
import "./funding/CollateralAccounts.sol";
import "./funding/BatchActions.sol";
import "./funding/Auctions.sol";

import "./lib/Transfer.sol";
import "./lib/Types.sol";
import "./lib/Consts.sol";
import "./lib/Requires.sol";
import "./lib/SafeMath.sol";

import "./interfaces/IStandardToken.sol";

/**
 * A collection of wrappers for all external methods in the protocol
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
        BatchActions.batch(state, actions, msg.value);
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
        returns (bool isValid)
    {
        isValid = Signature.isValidSignature(hash, signerAddress, signature);
    }

    ///////////////////////
    // Markets Functions //
    ///////////////////////

    function getAllMarketsCount()
        external
        view
        returns (uint256 count)
    {
        count = state.marketsCount;
    }

    function getAsset(address assetAddress)
        external
        view returns (Types.Asset memory asset)
    {
        Requires.requireAssetExist(state, assetAddress);
        asset = state.assets[assetAddress];
    }

    function getAssetOraclePrice(address assetAddress)
        external
        view
        returns (uint256 price)
    {
        Requires.requireAssetExist(state, assetAddress);
        price = AssemblyCall.getAssetPriceFromPriceOracle(
            address(state.assets[assetAddress].priceOracle),
            assetAddress
        );
    }

    function getMarket(uint16 marketID)
        external
        view
        returns (Types.Market memory market)
    {
        Requires.requireMarketIDExist(state, marketID);
        market = state.markets[marketID];
    }

    //////////////////////////////////
    // Collateral Account Functions //
    //////////////////////////////////

    function isAccountLiquidatable(
        address user,
        uint16 marketID
    )
        external
        view
        returns (bool isLiquidatable)
    {
        Requires.requireMarketIDExist(state, marketID);
        isLiquidatable = CollateralAccounts.getDetails(state, user, marketID).liquidatable;
    }

    function getAccountDetails(
        address user,
        uint16 marketID
    )
        external
        view
        returns (Types.CollateralAccountDetails memory details)
    {
        Requires.requireMarketIDExist(state, marketID);
        details = CollateralAccounts.getDetails(state, user, marketID);
    }

    function getAuctionsCount()
        external
        view
        returns (uint32 count)
    {
        count = state.auction.auctionsCount;
    }

    function getCurrentAuctions()
        external
        view
        returns (uint32[] memory)
    {
        return state.auction.currentAuctions;
    }

    function getAuctionDetails(uint32 auctionID)
        external
        view
        returns (Types.AuctionDetails memory details)
    {
        Requires.requireAuctionExist(state, auctionID);
        details = Auctions.getAuctionDetails(state, auctionID);
    }

    function fillAuctionWithAmount(
        uint32 auctionID,
        uint256 amount
    )
        external
    {
        Requires.requireAuctionExist(state, auctionID);
        Requires.requireAuctionNotFinished(state, auctionID);
        Auctions.fillAuctionWithAmount(state, auctionID, amount);
    }

    function liquidateAccount(
        address user,
        uint16 marketID
    )
        external
        returns (bool hasAuction, uint32 auctionID)
    {
        Requires.requireMarketIDExist(state, marketID);
        (hasAuction, auctionID) = Auctions.liquidate(state, user, marketID);
    }

    ///////////////////////////
    // LendingPool Functions //
    ///////////////////////////

    function getPoolCashableAmount(address asset)
        external
        view
        returns (uint256 cashableAmount)
    {
        if (asset == Consts.ETHEREUM_TOKEN_ADDRESS()) {
            cashableAmount = address(this).balance - uint256(state.cash[asset]);
        } else {
            cashableAmount = IStandardToken(asset).balanceOf(address(this)) - uint256(state.cash[asset]);
        }
    }

    function getIndex(address asset)
        external
        view
        returns (uint256 supplyIndex, uint256 borrowIndex)
    {
        return LendingPool.getCurrentIndex(state, asset);
    }

    function getTotalBorrow(address asset)
        external
        view
        returns (uint256 amount)
    {
        Requires.requireAssetExist(state, asset);
        amount = LendingPool.getTotalBorrow(state, asset);
    }

    function getTotalSupply(address asset)
        external
        view
        returns (uint256 amount)
    {
        Requires.requireAssetExist(state, asset);
        amount = LendingPool.getTotalSupply(state, asset);
    }

    function getAmountBorrowed(
        address asset,
        address user,
        uint16 marketID
    )
        external
        view
        returns (uint256 amount)
    {
        Requires.requireMarketIDExist(state, marketID);
        Requires.requireMarketIDAndAssetMatch(state, marketID, asset);
        amount = LendingPool.getAmountBorrowed(state, asset, user, marketID);
    }

    function getAmountSupplied(
        address asset,
        address user
    )
        external
        view
        returns (uint256 amount)
    {
        Requires.requireAssetExist(state, asset);
        amount = LendingPool.getAmountSupplied(state, asset, user);
    }

    function getInterestRates(
        address asset,
        uint256 extraBorrowAmount
    )
        external
        view
        returns (uint256 borrowInterestRate, uint256 supplyInterestRate)
    {
        Requires.requireAssetExist(state, asset);
        (borrowInterestRate, supplyInterestRate) = LendingPool.getInterestRates(state, asset, extraBorrowAmount);
    }

    function getInsuranceBalance(address asset)
        external
        view
        returns (uint256 amount)
    {
        Requires.requireAssetExist(state, asset);
        amount = state.pool.insuranceBalances[asset];
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
        returns (bool canMatch)
    {
        canMatch = Relayer.canMatchOrdersFrom(state, relayer);
    }

    function isParticipant(address relayer)
        external
        view
        returns (bool result)
    {
        result = Relayer.isParticipant(state, relayer);
    }

    ////////////////////////
    // Balances Functions //
    ////////////////////////

    function balanceOf(
        address asset,
        address user
    )
        external
        view
        returns (uint256 balance)
    {
        balance = Transfer.balanceOf(state,  BalancePath.getCommonPath(user), asset);
    }

    function marketBalanceOf(
        uint16 marketID,
        address asset,
        address user
    )
        external
        view
        returns (uint256 balance)
    {
        Requires.requireMarketIDExist(state, marketID);
        Requires.requireMarketIDAndAssetMatch(state, marketID, asset);
        balance = Transfer.balanceOf(state,  BalancePath.getMarketPath(user, marketID), asset);
    }

    function getMarketTransferableAmount(
        uint16 marketID,
        address asset,
        address user
    )
        external
        view
        returns (uint256 amount)
    {
        Requires.requireMarketIDExist(state, marketID);
        Requires.requireMarketIDAndAssetMatch(state, marketID, asset);
        amount = CollateralAccounts.getTransferableAmount(state, marketID, user, asset);
    }

    /** fallback function to allow deposit ether into this contract */
    function ()
        external
        payable
    {
        // deposit ${msg.value} ether for ${msg.sender}
        Transfer.deposit(
            state,
            Consts.ETHEREUM_TOKEN_ADDRESS(),
            msg.value
        );
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
        returns(bool isCancelled)
    {
        isCancelled = state.exchange.cancelled[orderHash];
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
        returns (uint256 rate)
    {
        rate = Discount.getDiscountedRate(state, user);
    }

    function getHydroTokenAddress()
        external
        view
        returns (address hydroTokenAddress)
    {
        hydroTokenAddress = state.exchange.hotTokenAddress;
    }

    function getOrderFilledAmount(
        bytes32 orderHash
    )
        external
        view
        returns (uint256 amount)
    {
        amount = state.exchange.filled[orderHash];
    }
}