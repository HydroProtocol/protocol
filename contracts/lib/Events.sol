/*

    Copyright 2019 The Hydro Protocol Foundation

    Licensed under the Apache License,
        Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing,
        software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
        either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "./Types.sol";

library Events {
    //////////////////
    // Funds moving //
    //////////////////

    // some assets move into contract
    event Deposit(
        address asset,
        address from,
        Types.BalancePath toPath,
        uint256 amount
    );

    function logDeposit(
        address asset,
        address from,
        Types.BalancePath memory toPath,
        uint256 amount
    )
        internal
    {
        emit Deposit(
            asset,
            from,
            toPath,
            amount
        );
    }

    // some assets move out of contract
    event Withdraw(
        address asset,
        Types.BalancePath fromPath,
        address to,
        uint256 amount
    );

    function logWithdraw(
        address asset,
        Types.BalancePath memory fromPath,
        address to,
        uint256 amount
    )
        internal
    {
        emit Withdraw(asset,
            fromPath,
            to,
            amount
        );
    }

    // internal assets movement
    event Transfer(
        address asset,
        Types.BalancePath fromPath,
        Types.BalancePath toPath,
        uint256 amount
    );

    function logTransfer(
        address asset,
        Types.BalancePath memory fromPath,
        Types.BalancePath memory toPath,
        uint256 amount
    )
        internal
    {
        emit Transfer(asset,
            fromPath,
            toPath,
            amount
        );
    }

    //////////////////
    // Lending Pool //
    //////////////////

    event Borrow(
        address user,
        uint16 marketID,
        address asset,
        uint256 amount
    );

    function logBorrow(
        address user,
        uint16 marketID,
        address asset,
        uint256 amount
    )
        internal
    {
        emit Borrow(
            user,
            marketID,
            asset,
            amount
        );
    }

    event Repay(
        address user,
        uint16 marketID,
        address asset,
        uint256 amount
    );

    function logRepay(
        address user,
        uint16 marketID,
        address asset,
        uint256 amount
    )
        internal
    {
        emit Repay(
            user,
            marketID,
            asset,
            amount
        );
    }

    event Supply(
        address user,
        address asset,
        uint256 amount
    );

    function logSupply(
        address user,
        address asset,
        uint256 amount
    )
        internal
    {
        emit Supply(
            user,
            asset,
            amount
        );
    }

    event Unsupply(
        address user,
        address asset,
        uint256 amount
    );

    function logUnsupply(
        address user,
        address asset,
        uint256 amount
    )
        internal
    {
        emit Unsupply(
            user,
            asset,
            amount
        );
    }


    ///////////////////
    // Admin Actions //
    ///////////////////

    event CreateMarket(Types.Market market);

    function logCreateMarket(
        Types.Market memory market
    )
        internal
    {
        emit CreateMarket(market);
    }

    event UpdateMarket(
        uint16 marketID,
        uint256 newAuctionRatioStart,
        uint256 newAuctionRatioPerBlock,
        uint256 newLiquidateRate,
        uint256 newWithdrawRate
    );

    function logUpdateMarket(
        uint16 marketID,
        uint256 newAuctionRatioStart,
        uint256 newAuctionRatioPerBlock,
        uint256 newLiquidateRate,
        uint256 newWithdrawRate
    )
        internal
    {
        emit UpdateMarket(
            marketID,
            newAuctionRatioStart,
            newAuctionRatioPerBlock,
            newLiquidateRate,
            newWithdrawRate
        );
    }

    event UpdateDiscountConfig(bytes32 newConfig);

    function logUpdateDiscountConfig(
        bytes32 newConfig
    )
        internal
    {
        emit UpdateDiscountConfig(newConfig);
    }

    event RegisterAsset(
        address asset,
        address oracleAddress,
        address poolTokenAddress
    );

    function logRegisterAsset(
        address asset,
        address oracleAddress,
        address poolTokenAddress
    )
        internal
    {
        emit RegisterAsset(asset,
            oracleAddress,
            poolTokenAddress
        );
    }

    event UpdateAssetPriceOracle(
        address asset,
        address oracleAddress
    );

    function logUpdateAssetPriceOracle(
        address asset,
        address oracleAddress
    )
        internal
    {
        emit UpdateAssetPriceOracle(
            asset,
            oracleAddress
        );
    }

    event UpdateAuctionInitiatorRewardRatio(
        uint256 newInitiatorRewardRatio
    );

    function logUpdateAuctionInitiatorRewardRatio(
        uint256 newInitiatorRewardRatio
    )
        internal
    {
        emit UpdateAuctionInitiatorRewardRatio(
            newInitiatorRewardRatio
        );
    }

    event UpdateInsuranceRatio(
        uint256 newInsuranceRatio
    );

    function logUpdateInsuranceRatio(
        uint256 newInsuranceRatio
    )
        internal
    {
        emit UpdateInsuranceRatio(newInsuranceRatio);
    }

    /////////////
    // Auction //
    /////////////

    // an auction is created
    event AuctionCreate(
        uint256 auctionID
    );

    function logAuctionCreate(
        uint256 auctionID
    )
        internal
    {
        emit AuctionCreate(auctionID);
    }

    // a user filled an acution
    event FillAuction(
        uint256 auctionID,
        uint256 filledAmount
    );

    function logFillAuction(
        uint256 auctionID,
        uint256 filledAmount
    )
        internal
    {
        emit FillAuction(
            auctionID,
            filledAmount
        );
    }

    // an auction is finished
    event AuctionFinished(
        uint256 auctionID
    );

    function logAuctionFinished(
        uint256 auctionID
    )
        internal
    {
        emit AuctionFinished(auctionID);
    }

    /////////////
    // Relayer //
    /////////////

    event RelayerApproveDelegate(
        address indexed relayer,
        address indexed delegate
    );

    function logRelayerApproveDelegate(
        address relayer,
        address delegate
    )
        internal
    {
        emit RelayerApproveDelegate(
            relayer,
            delegate
        );
    }

    event RelayerRevokeDelegate(
        address indexed relayer,
        address indexed delegate
    );

    function logRelayerRevokeDelegate(
        address relayer,
        address delegate
    )
        internal
    {
        emit RelayerRevokeDelegate(
            relayer,
            delegate
        );
    }

    event RelayerExit(
        address indexed relayer
    );

    function logRelayerExit(
        address relayer
    )
        internal
    {
        emit RelayerExit(relayer);
    }

    event RelayerJoin(
        address indexed relayer
    );

    function logRelayerJoin(
        address relayer
    )
        internal
    {
        emit RelayerJoin(relayer);
    }

    //////////////
    // Exchange //
    //////////////

    event Match(
        Types.OrderAddressSet addressSet,
        address maker,
        address taker,
        address buyer,
        uint256 makerFee,
        uint256 makerRebate,
        uint256 takerFee,
        uint256 makerGasFee,
        uint256 takerGasFee,
        uint256 baseAssetFilledAmount,
        uint256 quoteAssetFilledAmount

    );

    function logMatch(
        Types.MatchResult memory result,
        Types.OrderAddressSet memory addressSet
    )
        internal
    {
        emit Match(
            addressSet,
            result.maker,
            result.taker,
            result.buyer,
            result.makerFee,
            result.makerRebate,
            result.takerFee,
            result.makerGasFee,
            result.takerGasFee,
            result.baseAssetFilledAmount,
            result.quoteAssetFilledAmount
        );
    }

    event OrderCancel(
        bytes32 indexed orderHash
    );

    function logOrderCancel(
        bytes32 orderHash
    )
        internal
    {
        emit OrderCancel(orderHash);
    }
}