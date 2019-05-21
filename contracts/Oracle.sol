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

import "./lib/LibOwnable.sol";
import "./funding/Consts.sol";

contract Oracle is LibOwnable, Consts {

    // token price to ether price
    mapping(address => uint256) public tokenPrices;

    // price decimals is 18 (ORACLE_PRICE_BASE)
    function setPriceForToken(address token, uint256 price) public onlyOwner {
        tokenPrices[token] = price;
    }

    function getPriceForToken(address token) public view returns (uint256) {
        if (token == address(0))  {
            return ORACLE_PRICE_BASE;
        }

        return tokenPrices[token];
    }
}