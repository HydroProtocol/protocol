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

import "./Types.sol";

library Store {
    struct State {
        // collateral count
        uint256 collateralAccountCount;

        // a map to save all Margin collateral accounts
        mapping(uint256 => Types.CollateralAccount) allCollateralAccounts;

        // a map to save all funding collateral accounts
        mapping(address => uint256) userDefaultCollateralAccounts;

        uint256 assetsCount;

        mapping(uint256 => Types.Asset) assets;

        uint256 loansCount;

        //
        mapping(uint256 => Types.Loan) allLoans;

        //
        mapping(address => uint256[]) loansByBorrower;

        // asset balances (free to use money)
        mapping (address => mapping (address => uint)) balances;
    }
}