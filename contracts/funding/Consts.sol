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

contract Consts {
    uint256 internal constant SECONDS_OF_YEAR = 31536000;
    uint256 public constant INTEREST_RATE_BASE = 10000;
    uint256 public constant FEE_RATE_BASE = 10000;
    uint256 public constant RELAYER_FEE_RATE_BASE = 10000;
    uint256 public constant SIMULIZED_GAS_COST = 300000;

    uint256 public constant ORACLE_PRICE_BASE = 1000000000000000000;
}