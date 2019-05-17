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

import "../lib/LibOwnable.sol";

contract Assets is LibOwnable {
    struct Asset {
        address tokenAddress;
        uint256 collerateRate;
    }

    // assets order is very important, and we should not support any function to modify the order.
    Asset[] public allAssets;
    mapping(address => uint256) public allAssetsMap;

    event AssetCreated(Asset asset);

    modifier onlyAssetNotExist(address tokenAddress) {
        require(allAssets[allAssetsMap[tokenAddress]].tokenAddress == address(0), "ASSET_IS_ALREADY_EXIST");
        _;
    }

    modifier onlyAssetExist(address tokenAddress) {
        require(allAssets[allAssetsMap[tokenAddress]].tokenAddress != address(0), "ASSET_IS_NOT_ALREADY_EXIST");
        _;
    }

    function getAllAssetsCount() public view returns (uint256) {
        return allAssets.length;
    }

    function addAsset(address tokenAddress, uint256 collerateRate)
        public
        onlyOwner
        onlyAssetNotExist(tokenAddress)
    {
        Asset memory asset = Asset(tokenAddress, collerateRate);
        uint256 index = allAssets.push(asset);
        allAssetsMap[tokenAddress] = index;
        emit AssetCreated(asset);
    }
}