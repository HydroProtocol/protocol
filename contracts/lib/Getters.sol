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

import "./SafeMath.sol";
import "./Types.sol";
import "./Consts.sol";
import "./Store.sol";
import "./Decimal.sol";

library Getters {
    using SafeMath for uint256;

    // pool functions

    function _getPoolSupply(Store.State storage state, uint16 assetID, address user) internal view returns (uint256){
        (uint256 currentSupplyIndex, ) = _getPoolCurrentIndex(state, assetID);
        return Decimal.mul(state.PoolState.logicSupply[assetID][user], currentSupplyIndex);
    }

    function _getPoolBorrow(Store.State storage state, uint16 assetID, uint32 account) internal view returns (uint256){
        (, uint256 currentBorrowIndex) = _getPoolCurrentIndex(state, assetID);
        return Decimal.mul(state.PoolState.logicBorrow[assetID][user], currentBorrowIndex);
    }

    function _getPoolTotalSupply(Store.State storage state, uint16 assetID) internal view returns (uint256){
        (uint256 currentSupplyIndex, ) = _getPoolCurrentIndex(state, assetID);
        return Decimal.mul(state.PoolState.logicTotalSupply[assetID], currentSupplyIndex);
    }

    function _getPoolTotalBorrow(Store.State storage state, uint16 assetID) internal view returns (uint256){
        (, uint256 currentBorrowIndex) = _getPoolCurrentIndex(state, assetID);
        return Decimal.mul(state.PoolState.logicTotalBorrow[assetID], currentBorrowIndex);
    }

    function _getPoolCurrentIndex(Store.State storage state, uint16 assetID) internal view returns (uint256 currentSupplyIndex, uint256 currentBorrowIndex){
         uint256 borrowInterestRate = state.pool.borrowAnnualInterestRate[assetID]
            .mul(block.timestamp.sub(state.pool.indexStartTime[assetID]))
            .div(Consts.SECONDS_OF_YEAR());
         uint256 supplyInterestRate = state.pool.supplyAnnualInterestRate[assetID]
            .mul(block.timestamp.sub(state.pool.indexStartTime[assetID]))
            .div(Consts.SECONDS_OF_YEAR());

        currentBorrowIndex = Decimal.mul(state.pool.borrowIndex[assetID], Decimal.onePlus(borrowInterestRate));
        currentSupplyIndex = Decimal.mul(state.pool.supplyIndex[assetID], Decimal.onePlus(supplyInterestRate));

        return (currentSupplyIndex, currentBorrowIndex);
    }

}