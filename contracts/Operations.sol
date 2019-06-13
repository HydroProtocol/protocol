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
import "./funding/Markets.sol";
import "./exchange/Discount.sol";
import "./interfaces/IOracle.sol";

/**
 * Only owner can use this contract functions
 */
contract Operations is Ownable, GlobalStore, Modifiers {

    function addMarket(
        Types.Market calldata market
    )
        external
        onlyOwner
        requireMarketAssetsValid(market)
        requireMarketNotExist(market)
        decimalLessOrEquanThanOne(market.auctionRatioStart)
        decimalLessOrEquanThanOne(market.auctionRatioPerBlock)
    {
        uint16 marketID = state.marketsCount;
        Markets.addMarket(state, market);
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
        requireAssetNotExist(asset)
    {
        state.oracles[asset] = IOracle(oracleAddress);
        Pool.createAssetPool(state, asset);
        Pool.createPoolToken(state, asset, poolTokenName, poolTokenSymbol, poolTokenDecimals);
        // TODO event
    }

    /**
     * @param newConfig A data blob representing the new discount config. Details on format above.
     */
    function changeDiscountConfig(
        bytes32 newConfig
    )
        external
        onlyOwner
    {
        Discount.changeDiscountConfig(state, newConfig);
    }

    function changeAuctionParams(
        uint16 marketID,
        uint256 newAuctionRatioStart,
        uint256 newAuctionRatioPerBlock
    )
        external
        onlyOwner
        decimalLessOrEquanThanOne(newAuctionRatioStart)
        decimalLessOrEquanThanOne(newAuctionRatioPerBlock)
    {
        state.markets[marketID].auctionRatioStart = newAuctionRatioStart;
        state.markets[marketID].auctionRatioPerBlock = newAuctionRatioPerBlock;
    }

    function changeAuctionInitiatorRewardRatio(
        uint256 newInitiatorRewardRatio
    )
        external
        onlyOwner
        decimalLessOrEquanThanOne(newInitiatorRewardRatio)
    {
        state.auction.initiatorRewardRatio = newInitiatorRewardRatio;
    }

    function changeInsuranceRatio(
        uint256 newInsuranceRatio
    )
        external
        onlyOwner
        decimalLessOrEquanThanOne(newInsuranceRatio)
    {
        state.insuranceRatio = newInsuranceRatio;
    }
}