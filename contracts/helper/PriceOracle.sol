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

import "../lib/Ownable.sol";

/**
 * A simple static oracle for test purpose.
 */
contract PriceOracle is Ownable {

    // token price to ether price
    mapping(address => uint256) public tokenPrices;

    // price decimals is 18
    function setPrice(
        address asset,
        uint256 price
    ) external onlyOwner {
        tokenPrices[asset] = price;
    }

    function getPrice(
        address asset
    )
        external
        view
        returns (uint256)
    {
        return tokenPrices[asset];
    }
}