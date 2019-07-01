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

import "./lib/Requires.sol";
import "./lib/Events.sol";
import "./lib/Types.sol";
import "./funding/LendingPool.sol";
import "./exchange/Exchange.sol";
import "./interfaces/IPriceOracle.sol";
import "./funding/LendingPoolTokenFactory.sol";

/**
 * Only owner can use this contract functions
 */
library OperationsLib {

    function createMarket(
        Store.State storage state,
        Types.Market memory market
    )
        public
    {
        Requires.requireMarketAssetsValid(state, market);
        Requires.requireMarketNotExist(state, market);
        Requires.requireDecimalLessOrEquanThanOne(market.auctionRatioStart);
        Requires.requireDecimalLessOrEquanThanOne(market.auctionRatioPerBlock);
        Requires.requireDecimalGreaterThanOne(market.liquidateRate);
        Requires.requireDecimalGreaterThanOne(market.withdrawRate);

        state.markets[state.marketsCount++] = market;
        Events.logCreateMarket(market);
    }

    function updateMarket(
        Store.State storage state,
        uint16 marketID,
        uint256 newAuctionRatioStart,
        uint256 newAuctionRatioPerBlock,
        uint256 newLiquidateRate,
        uint256 newWithdrawRate
    )
        external
    {
        Requires.requireMarketIDExist(state, marketID);
        Requires.requireDecimalLessOrEquanThanOne(newAuctionRatioStart);
        Requires.requireDecimalLessOrEquanThanOne(newAuctionRatioPerBlock);
        Requires.requireDecimalGreaterThanOne(newLiquidateRate);
        Requires.requireDecimalGreaterThanOne(newWithdrawRate);

        state.markets[marketID].auctionRatioStart = newAuctionRatioStart;
        state.markets[marketID].auctionRatioPerBlock = newAuctionRatioPerBlock;
        state.markets[marketID].liquidateRate = newLiquidateRate;
        state.markets[marketID].withdrawRate = newWithdrawRate;

        Events.logUpdateMarket(
            marketID,
            newAuctionRatioStart,
            newAuctionRatioPerBlock,
            newLiquidateRate,
            newWithdrawRate
        );
    }

    function createAsset(
        Store.State storage state,
        address asset,
        address oracleAddress,
        address interestModalAddress,
        string calldata poolTokenName,
        string calldata poolTokenSymbol,
        uint8 poolTokenDecimals
    )
        external
    {
        Requires.requirePriceOracleAddressValid(oracleAddress);
        Requires.requireAssetNotExist(state, asset);

        LendingPool.initializeAssetLendingPool(state, asset);

        state.assets[asset].priceOracle = IPriceOracle(oracleAddress);
        state.assets[asset].interestModel = IInterestModel(interestModalAddress);
        state.assets[asset].lendingPoolToken = LendingPoolTokenFactory.create(
            poolTokenName,
            poolTokenSymbol,
            poolTokenDecimals
        );

        Events.logCreateAsset(
            asset,
            oracleAddress,
            address(state.assets[asset].lendingPoolToken),
            interestModalAddress
        );
    }

    function updateAsset(
        Store.State storage state,
        address asset,
        address oracleAddress,
        address interestModalAddress
    )
        external
    {
        Requires.requirePriceOracleAddressValid(oracleAddress);
        Requires.requireAssetExist(state, asset);

        state.assets[asset].priceOracle = IPriceOracle(oracleAddress);
        state.assets[asset].interestModel = IInterestModel(interestModalAddress);

        Events.logUpdateAsset(
            asset,
            oracleAddress,
            interestModalAddress
        );
    }

    /**
     * @param newConfig A data blob representing the new discount config. Details on format above.
     */
    function updateDiscountConfig(
        Store.State storage state,
        bytes32 newConfig
    )
        external
    {
        state.exchange.discountConfig = newConfig;
        Events.logUpdateDiscountConfig(newConfig);
    }

    function updateAuctionInitiatorRewardRatio(
        Store.State storage state,
        uint256 newInitiatorRewardRatio
    )
        external
    {
        Requires.requireDecimalLessOrEquanThanOne(newInitiatorRewardRatio);

        state.auction.initiatorRewardRatio = newInitiatorRewardRatio;
        Events.logUpdateAuctionInitiatorRewardRatio(newInitiatorRewardRatio);
    }

    function updateInsuranceRatio(
        Store.State storage state,
        uint256 newInsuranceRatio
    )
        external
    {
        Requires.requireDecimalLessOrEquanThanOne(newInsuranceRatio);

        state.pool.insuranceRatio = newInsuranceRatio;
        Events.logUpdateInsuranceRatio(newInsuranceRatio);
    }
}