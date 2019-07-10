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

import "./StandardToken.sol";

/**
 * Test wrapper
 */
contract TestToken is StandardToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint public totalSupply = 1560000000 * 10**18;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
        public
    {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        balances[msg.sender] = totalSupply;
    }
}