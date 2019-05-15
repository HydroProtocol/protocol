/*

    Copyright 2018 The Hydro Protocol Foundation

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

import "./lib/SafeMath.sol";
import "./lib/LibWhitelist.sol";
import "./lib/LibSafeERC20Transfer.sol";

contract Proxy is LibWhitelist, LibSafeERC20Transfer {
    using SafeMath for uint256;

    mapping( address => uint256 ) public balances;

    event Deposit(address owner, uint256 amount);
    event Withdraw(address owner, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function depositEther() public payable {
        balances[msg.sender] = balances[msg.sender].add(msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdrawEther(uint256 amount) public {
        balances[msg.sender] = balances[msg.sender].sub(amount);
        msg.sender.transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    function () external payable {
        depositEther();
    }

    /// @dev Invoking transferFrom.
    /// @param token Address of token to transfer.
    /// @param from Address to transfer token from.
    /// @param to Address to transfer token to.
    /// @param value Amount of token to transfer.
    function transferFrom(address token, address from, address to, uint256 value)
        external
        onlyAddressInWhitelist
    {
        if (token == address(0)) {
            transferEther(from, to, value);
        } else {
            safeTransferFrom(token, from, to, value);
        }
    }

    function transferEther(address from, address to, uint256 value)
        internal
        onlyAddressInWhitelist
    {
        balances[from] = balances[from].sub(value);
        balances[to] = balances[to].add(value);

        emit Transfer(from, to, value);
    }
}