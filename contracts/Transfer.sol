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

import "./Store.sol";
import "./lib/SafeMath.sol";
import "./lib/LibSafeERC20Transfer.sol";

/**
 * Global state store
 */
contract Transfer is Store {
    using SafeMath for uint256;

    // event Deposit(address token, address account, uint256 amount, uint256 balance);
    // event Withdraw(address token, address account, uint256 amount, uint256 balance);
    // event Transfer(address indexed from, address indexed to, uint256 amount);

    // deposit token need approve first.
    function deposit(address token, uint256 amount) public payable {
        depositFor(token, msg.sender, msg.sender, amount);
    }

    function depositFor(address token, address from, address to, uint256 amount) public payable {
        if (amount == 0) {
            return;
        }

        mapping (address => mapping (address => uint)) storage balances = state.balances;

        if (token != address(0)) {
            LibSafeERC20Transfer.safeTransferFrom(token, from, address(this), amount);
        } else {
            require(amount == msg.value, "Wrong amount");
        }

        balances[token][to] = balances[token][to].add(amount);
        emit Deposit(token, to, amount, balances[token][to]);
    }

    function withdraw(address token, uint256 amount) external {
        withdrawTo(token, msg.sender, msg.sender, amount);
    }

    function withdrawTo(address token, address from, address payable to, uint256 amount) public {
        if (amount == 0) {
            return;
        }

        mapping (address => mapping (address => uint)) storage balances = state.balances;

        require(balances[token][from] >= amount, "BALANCE_NOT_ENOUGH");

        balances[token][from] = balances[token][from].sub(amount);

        if (token == address(0)) {
            to.transfer(amount);
        } else {
            safeTransfer(token, to, amount);
        }

        emit Withdraw(token, from, amount, balances[token][from]);
    }

    function () external payable {
        deposit(address(0), msg.value);
    }

    function balanceOf(address token, address account) public view returns (uint256) {
        return state.balances[token][account];
    }

    /** @dev Invoking internal funds transfer.
      * @param token Address of token to transfer.
      * @param from Address to transfer token from.
      * @param to Address to transfer token to.
      * @param amount Amount of token to transfer.
      */
    function transferFrom(address token, address from, address to, uint256 amount)
      internal
    //   onlyAddressInWhitelist
    {
        mapping (address => mapping (address => uint)) storage balances = state.balances;

        // do nothing when amount is zero
        if (amount == 0) {
            return;
        }

        require(balances[token][from] >= amount, "TRANSFER_BALANCE_NOT_ENOUGH");

        balances[token][from] = balances[token][from].sub(amount);
        balances[token][to] = balances[token][to].add(amount);

        // TODO: emit Transfer(from, to, amount);
    }
}