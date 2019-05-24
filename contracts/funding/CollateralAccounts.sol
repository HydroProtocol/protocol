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

contract CollateralAccounts {

    // collateral count
    uint256 public collateralAccountCount;

    // a map to save all Margin collateral accounts
    mapping(uint256 => CollateralAccount) public allCollateralAccounts;

    // a map to save all funding collateral accounts
    mapping(address => CollateralAccount) public defaultCollateralAccounts;

    struct CollateralAccount {
        address owner;
        mapping(uint256 => uint256) assetAmounts;
    }

    function findOrCreateDefaultCollateralAccount(address user) internal returns (CollateralAccount storage) {
        if(defaultCollateralAccounts[user].owner == address(0)) {
            defaultCollateralAccounts[user] = CollateralAccount({
                owner: user
            });
        }

        return defaultCollateralAccounts[user];
    }

    function createCollateralAccount(address user)internal returns (CollateralAccount storage) {
        CollateralAccount memory account = CollateralAccount({
            owner: user
        });

        uint256 id = collateralAccountCount++;

        allCollateralAccounts[id] = account;

        return allCollateralAccounts[id];
    }
}