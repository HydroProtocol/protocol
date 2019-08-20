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

/**
 * Library to define and emit Events
 */
library Events {
    //////////////////
    // Funds moving //
    //////////////////

    // some assets move into contract
    event Deposit(
        address indexed user,
        address indexed asset,
        uint256 amount
    );

    function logDeposit(
        address user,
        address asset,
        uint256 amount
    )
        internal
    {
        emit Deposit(
            user,
            asset,
            amount
        );
    }

    // some assets move out of contract
    event Withdraw(
        address indexed user,
        address indexed asset,
        uint256 amount
    );

    function logWithdraw(
        address user,
        address asset,
        uint256 amount
    )
        internal
    {
        emit Withdraw(
            user,
            asset,
            amount
        );
    }

    // transfer from balance to collateral account
    event IncreaseCollateral (
        address indexed user,
        uint16 indexed marketID,
        address indexed asset,
        uint256 amount
    );

    function logIncreaseCollateral(
        address user,
        uint16 marketID,
        address asset,
        uint256 amount
    )
        internal
    {
        emit IncreaseCollateral(
            user,
            marketID,
            asset,
            amount
        );
    }

    // transfer from collateral account to balance
    event DecreaseCollateral (
        address indexed user,
        uint16 indexed marketID,
        address indexed asset,
        uint256 amount
    );

    function logDecreaseCollateral(
        address user,
        uint16 marketID,
        address asset,
        uint256 amount
    )
        internal
    {
        emit DecreaseCollateral(
            user,
            marketID,
            asset,
            amount
        );
    }

    //////////////////
    // Lending Pool //
    //////////////////

    event UpdateIndex(
        address indexed asset,
        uint256 oldBorrowIndex,
        uint256 newBorrowIndex,
        uint256 oldSupplyIndex,
        uint256 newSupplyIndex
    );

    function logUpdateIndex(
        address asset,
        uint256 oldBorrowIndex,
        uint256 newBorrowIndex,
        uint256 oldSupplyIndex,
        uint256 newSupplyIndex
    )
        internal
    {
        emit UpdateIndex(
            asset,
            oldBorrowIndex,
            newBorrowIndex,
            oldSupplyIndex,
            newSupplyIndex
        );
    }

    event Borrow(
        address indexed user,
        uint16 indexed marketID,
        address indexed asset,
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
        address indexed user,
        uint16 indexed marketID,
        address indexed asset,
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
        address indexed user,
        address indexed asset,
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
        address indexed user,
        address indexed asset,
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

    event Loss(
        address indexed asset,
        uint256 amount
    );

    function logLoss(
        address asset,
        uint256 amount
    )
        internal
    {
        emit Loss(
            asset,
            amount
        );
    }

    event InsuranceCompensation(
        address indexed asset,
        uint256 amount
    );

    function logInsuranceCompensation(
        address asset,
        uint256 amount
    )
        internal
    {
        emit InsuranceCompensation(
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
        uint16 indexed marketID,
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

    event MarketBorrowDisable(
        uint16 indexed marketID
    );

    function logMarketBorrowDisable(
        uint16 marketID
    )
        internal
    {
        emit MarketBorrowDisable(
            marketID
        );
    }

    event MarketBorrowEnable(
        uint16 indexed marketID
    );

    function logMarketBorrowEnable(
        uint16 marketID
    )
        internal
    {
        emit MarketBorrowEnable(
            marketID
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

    event CreateAsset(
        address asset,
        address oracleAddress,
        address poolTokenAddress,
        address interestModelAddress
    );

    function logCreateAsset(
        address asset,
        address oracleAddress,
        address poolTokenAddress,
        address interestModelAddress
    )
        internal
    {
        emit CreateAsset(
            asset,
            oracleAddress,
            poolTokenAddress,
            interestModelAddress
        );
    }

    event UpdateAsset(
        address indexed asset,
        address oracleAddress,
        address interestModelAddress
    );

    function logUpdateAsset(
        address asset,
        address oracleAddress,
        address interestModelAddress
    )
        internal
    {
        emit UpdateAsset(
            asset,
            oracleAddress,
            interestModelAddress
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

    event Liquidate(
        address indexed user,
        uint16 indexed marketID,
        bool indexed hasAuction
    );

    function logLiquidate(
        address user,
        uint16 marketID,
        bool hasAuction
    )
        internal
    {
        emit Liquidate(
            user,
            marketID,
            hasAuction
        );
    }

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
        uint256 indexed auctionID,
        address bidder,
        uint256 repayDebt,
        uint256 bidderRepayDebt,
        uint256 bidderCollateral,
        uint256 leftDebt
    );

    function logFillAuction(
        uint256 auctionID,
        address bidder,
        uint256 repayDebt,
        uint256 bidderRepayDebt,
        uint256 bidderCollateral,
        uint256 leftDebt
    )
        internal
    {
        emit FillAuction(
            auctionID,
            bidder,
            repayDebt,
            bidderRepayDebt,
            bidderCollateral,
            leftDebt
        );
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