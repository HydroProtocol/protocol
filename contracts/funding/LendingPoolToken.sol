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
import "../helper/StandardToken.sol";

/**
 * A new kind of lending pool token will be created when a new asset is registered.
 * Normalized amounts of the asset in lending pool are stored in the corresponding
 * pool token contract as balance.
 */
contract LendingPoolToken is StandardToken, Ownable {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    event Mint(address indexed user, uint256 value);
    event Burn(address indexed user, uint256 value);

    constructor (
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals
    )
        public
    {
        name = tokenName;
        symbol = tokenSymbol;
        decimals = tokenDecimals;
    }

    function mint(
        address user,
        uint256 value
    )
        external
        onlyOwner
    {
        balances[user] = balances[user].add(value);
        totalSupply = totalSupply.add(value);
        emit Mint(user, value);
    }

    function burn(
        address user,
        uint256 value
    )
        external
        onlyOwner
    {
        balances[user] = balances[user].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Burn(user, value);
    }

}