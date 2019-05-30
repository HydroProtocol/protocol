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
pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "../lib/Store.sol";
import "../lib/Types.sol";
import "../lib/Events.sol";
import "../interfaces/OracleInterface.sol";

library Assets {
    modifier onlyAssetNotExist(Store.State storage state, address tokenAddress) {
        require(!isAssetExist(state, tokenAddress), "TOKEN_IS_ALREADY_EXIST");
        _;
    }

    function isAssetExist(Store.State storage state, address tokenAddress) internal view returns (bool) {
        for(uint256 i = 0; i < state.assetsCount; i++) {
            if (state.assets[i].tokenAddress == tokenAddress) {
                return true;
            }
        }

        return false;
    }

    function getAsset(Store.State storage state, uint16 assetID) internal view returns (Types.Asset memory) {
        return state.assets[assetID];
    }

    function getAllAssetsCount(Store.State storage state) internal view returns (uint256) {
        return state.assetsCount;
    }

    function addAsset(Store.State storage state, address tokenAddress, uint256 collerateRate, address oracleAddress)
        internal
        onlyAssetNotExist(state, tokenAddress)
    {
        Types.Asset memory asset = Types.Asset(tokenAddress, collerateRate, OracleInterface(oracleAddress));
        uint256 index = state.assetsCount++;
        state.assets[index] = asset;

        Events.logAssetCreate(asset);
    }

    function getAssetIDByAddress(Store.State storage state, address tokenAddress) internal view returns (uint16 assetID) {
        for( uint16 i = 0; i < state.assetsCount; i++ ) {
            if( tokenAddress == state.assets[i].tokenAddress ) {
                return i;
            }
        }

        revert("CAN_NOT_FIND_ASSET_ID");
    }
}