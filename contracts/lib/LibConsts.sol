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

library LibConsts {
    uint256 internal constant SECONDS_OF_YEAR = 31536000;
    uint256 internal constant INTEREST_RATE_BASE = 10000;
    uint256 internal constant FEE_RATE_BASE = 10000;
    uint256 internal constant RELAYER_FEE_RATE_BASE = 10000;
    uint256 internal constant SIMULIZED_GAS_COST = 300000;

    uint256 internal constant ORACLE_PRICE_BASE = 1000000000000000000;

    function getSecondsOfYear() internal pure returns(uint256){return SECONDS_OF_YEAR;}
    function getInterestRateBase() internal pure returns(uint256){return INTEREST_RATE_BASE;}
    function getFeeRateBase() internal pure returns(uint256){return FEE_RATE_BASE;}
    function getRelayerFeeRateBase() internal pure returns(uint256){return RELAYER_FEE_RATE_BASE;}
    function getSimulizedGasCost() internal pure returns(uint256){return SIMULIZED_GAS_COST;}
    function getOraclePriceBase() internal pure returns(uint256){return ORACLE_PRICE_BASE;}
}