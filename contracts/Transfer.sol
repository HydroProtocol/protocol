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

import "./GlobalStore.sol";

import "./lib/Events.sol";
import "./lib/SafeMath.sol";
import "./lib/SafeERC20.sol";

contract Transfer is GlobalStore {
    using SafeMath for uint256;

    /** @dev deposit asset
      * @param asset   Address of asset to transfer.
      * @param amount  Amount of asset to transfer.
      */
    function deposit(address asset, uint256 amount) public payable {
        depositFor(asset, msg.sender, msg.sender, amount);
    }

    /** @dev Transfer asset into current contract
      * @param asset   Address of asset to transfer.
      * @param from    Address of asset owner.
      * @param to      Address of the receiver.
      * @param amount  Amount of asset to transfer.
      */
    function depositFor(address asset, address from, address to, uint256 amount) public payable {
        if (amount == 0) {
            return;
        }

        mapping (address => mapping (address => uint)) storage balances = state.balances;

        if (asset != address(0)) {
            SafeERC20.safeTransferFrom(asset, from, address(this), amount);
        } else {
            require(amount == msg.value, "Wrong amount");
        }

        balances[asset][to] = balances[asset][to].add(amount);
        Events.logDeposit(asset, from, to, amount);
    }

    /** @dev withdraw asset
      * @param asset   Address of asset to transfer.
      * @param amount  Amount of asset to transfer.
      */
    function withdraw(address asset, uint256 amount) public {
        withdrawTo(asset, msg.sender, msg.sender, amount);
    }

    /** @dev Transfer asset out of current contract
      * @param asset   Address of asset to transfer.
      * @param from    Address of asset owner.
      * @param to      Address of the receiver.
      * @param amount  Amount of asset to transfer.
      */
    function withdrawTo(address asset, address from, address payable to, uint256 amount) public {
        if (amount == 0) {
            return;
        }

        mapping (address => mapping (address => uint)) storage balances = state.balances;

        require(balances[asset][from] >= amount, "BALANCE_NOT_ENOUGH");

        balances[asset][from] = balances[asset][from].sub(amount);

        if (asset == address(0)) {
            to.transfer(amount);
        } else {
            SafeERC20.safeTransfer(asset, to, amount);
        }

        Events.logWithdraw(asset, from, to, amount);
    }

    /** @dev fallback function to allow deposit ether into this contract */
    function () external payable {

        // deposit ${msg.value} ether for ${msg.sender}
        deposit(address(0), msg.value);
    }

    /** @dev Get a user's asset balance
      * @param asset  Address of asset
      * @param user   Address of user
      */
    function balanceOf(address asset, address user) public view returns (uint256) {
        return state.balances[asset][user];
    }

    /** @dev Invoking internal funds transfer.
      * @param asset   Address of asset to transfer.
      * @param from    Address to transfer asset from.
      * @param to      Address to transfer asset to.
      * @param amount  Amount of asset to transfer.
      */
    function transferFrom(address asset, address from, address to, uint256 amount)
      internal
    {
        mapping (address => mapping (address => uint)) storage balances = state.balances;

        // do nothing when amount is zero
        if (amount == 0) {
            return;
        }

        require(balances[asset][from] >= amount, "TRANSFER_BALANCE_NOT_ENOUGH");

        balances[asset][from] = balances[asset][from].sub(amount);
        balances[asset][to] = balances[asset][to].add(amount);

        Events.logTransfer(asset, from, to, amount);
    }
}