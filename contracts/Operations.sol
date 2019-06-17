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

import "./lib/Ownable.sol";
import "./lib/Types.sol";
import "./funding/Pool.sol";
import "./exchange/Discount.sol";
import "./interfaces/IOracle.sol";

/**
 * Only owner can use this contract functions
 */
contract Operations is Ownable, GlobalStore, Modifiers {

    function addMarket(
        Types.Market memory market
    )
        public
        onlyOwner
        requireMarketAssetsValid(market)
        requireMarketNotExist(market)
        requireDecimalLessOrEquanThanOne(market.auctionRatioStart)
        requireDecimalLessOrEquanThanOne(market.auctionRatioPerBlock)
        requireDecimalGreaterThanOne(market.liquidateRate)
        requireDecimalGreaterThanOne(market.withdrawRate)
    {
        state.markets[state.marketsCount++] = market;
        Events.logMarketCreate(market);
    }

    function updateMarket(
        uint16 marketID,
        uint256 newAuctionRatioStart,
        uint256 newAuctionRatioPerBlock,
        uint256 newLiquidateRate,
        uint256 newWithdrawRate
    )
        external
        onlyOwner
        requireDecimalLessOrEquanThanOne(newAuctionRatioStart)
        requireDecimalLessOrEquanThanOne(newAuctionRatioPerBlock)
        requireDecimalGreaterThanOne(newLiquidateRate)
        requireDecimalGreaterThanOne(newWithdrawRate)
    {
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

    function registerAsset(
        address asset,
        address oracleAddress,
        string calldata poolTokenName,
        string calldata poolTokenSymbol,
        uint8 poolTokenDecimals
    )
        external
        onlyOwner
        requireOracleAddressValid(oracleAddress)
        requireAssetNotExist(asset)
    {
        state.oracles[asset] = IOracle(oracleAddress);
        Pool.initializeAssetPool(state, asset);

        address poolTokenAddress = Pool.createPoolToken(
            state,
            asset,
            poolTokenName,
            poolTokenSymbol,
            poolTokenDecimals
        );

        Events.logRegisterAsset(
            asset,
            oracleAddress,
            poolTokenAddress
        );
    }

    function updateAssetOracle(
        address asset,
        address oracleAddress
    )
        external
        onlyOwner
        requireOracleAddressValid(oracleAddress)
        requireAssetExist(asset)
    {
        state.oracles[asset] = IOracle(oracleAddress);

        Events.logUpdateAssetOracle(
            asset,
            oracleAddress
        );
    }

    /**
     * @param newConfig A data blob representing the new discount config. Details on format above.
     */
    function updateDiscountConfig(
        bytes32 newConfig
    )
        external
        onlyOwner
    {
        state.exchange.discountConfig = newConfig;
        Events.logUpdateDiscountConfig(newConfig);
    }

    function updateAuctionInitiatorRewardRatio(
        uint256 newInitiatorRewardRatio
    )
        external
        onlyOwner
        requireDecimalLessOrEquanThanOne(newInitiatorRewardRatio)
    {
        state.auction.initiatorRewardRatio = newInitiatorRewardRatio;
        Events.logUpdateAuctionInitiatorRewardRatio(newInitiatorRewardRatio);
    }

    function updateInsuranceRatio(
        uint256 newInsuranceRatio
    )
        external
        onlyOwner
        requireDecimalLessOrEquanThanOne(newInsuranceRatio)
    {
        state.pool.insuranceRatio = newInsuranceRatio;
        Events.logUpdateInsuranceRatio(newInsuranceRatio);
    }
}