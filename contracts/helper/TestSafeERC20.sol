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

import "../lib/SafeERC20.sol";
import "./TestToken.sol";

/**
 * Test wrapper
 */
contract TestSafeERC20 {
    address public tokenAddress;

    constructor ()
        public
    {
        tokenAddress = address(new TestToken("test", "test", 18));
    }

    // transfer token out
    function transfer(
        address to,
        uint256 amount
    )
        public
    {
        SafeERC20.safeTransfer(tokenAddress, to, amount);
    }
}