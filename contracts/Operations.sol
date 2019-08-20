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
import "./lib/Ownable.sol";
import "./lib/Types.sol";
import "./components/OperationsComponent.sol";

/**
 * Admin operations
 */
contract Operations is Ownable, GlobalStore {

    function createMarket(
        Types.Market memory market
    )
        public
        onlyOwner
    {
        OperationsComponent.createMarket(state, market);
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
    {
        OperationsComponent.updateMarket(
            state,
            marketID,
            newAuctionRatioStart,
            newAuctionRatioPerBlock,
            newLiquidateRate,
            newWithdrawRate
        );
    }

    function setMarketBorrowUsability(
        uint16 marketID,
        bool   usability
    )
        external
        onlyOwner
    {
        OperationsComponent.setMarketBorrowUsability(
            state,
            marketID,
            usability
        );
    }

    function createAsset(
        address asset,
        address oracleAddress,
        address interestModelAddress,
        string calldata poolTokenName,
        string calldata poolTokenSymbol,
        uint8 poolTokenDecimals
    )
        external
        onlyOwner
    {
        OperationsComponent.createAsset(
            state,
            asset,
            oracleAddress,
            interestModelAddress,
            poolTokenName,
            poolTokenSymbol,
            poolTokenDecimals
        );
    }

    function updateAsset(
        address asset,
        address oracleAddress,
        address interestModelAddress
    )
        external
        onlyOwner
    {
        OperationsComponent.updateAsset(
            state,
            asset,
            oracleAddress,
            interestModelAddress
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
        OperationsComponent.updateDiscountConfig(
            state,
            newConfig
        );
    }

    function updateAuctionInitiatorRewardRatio(
        uint256 newInitiatorRewardRatio
    )
        external
        onlyOwner
    {
        OperationsComponent.updateAuctionInitiatorRewardRatio(
            state,
            newInitiatorRewardRatio
        );
    }

    function updateInsuranceRatio(
        uint256 newInsuranceRatio
    )
        external
        onlyOwner
    {
        OperationsComponent.updateInsuranceRatio(
            state,
            newInsuranceRatio
        );
    }
}