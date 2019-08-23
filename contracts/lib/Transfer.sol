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

import "./Events.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./Consts.sol";
import "./Store.sol";
import "./Types.sol";
import "./Requires.sol";
import "../funding/CollateralAccounts.sol";

/**
 * Library to moving assets
 */
library Transfer {
    using SafeMath for uint256;
    using SafeMath for int256;
    using BalancePath for Types.BalancePath;

    // Transfer asset into current contract
    function deposit(
        Store.State storage state,
        address asset,
        uint256 amount
    )
        internal
        returns (uint256)
    {
        uint256 depositedEtherAmount = 0;

        if (asset == Consts.ETHEREUM_TOKEN_ADDRESS()) {
            // Since this method is able to be called in batch,
            // there is a chance that a batch contains multi deposit ether calls.
            // To make sure the the msg.value is equal to the total deposit ethers,
            // each ether deposit function needs to return the actual deposited ether amount.
            depositedEtherAmount = amount;
        } else {
            SafeERC20.safeTransferFrom(asset, msg.sender, address(this), amount);
        }

        transferIn(state, asset, BalancePath.getCommonPath(msg.sender), amount);
        Events.logDeposit(msg.sender, asset, amount);

        return depositedEtherAmount;
    }

    // Transfer asset out of current contract
    function withdraw(
        Store.State storage state,
        address user,
        address asset,
        uint256 amount
    )
        internal
    {
        require(state.balances[user][asset] >= amount, "BALANCE_NOT_ENOUGH");

        if (asset == Consts.ETHEREUM_TOKEN_ADDRESS()) {
            address payable payableUser = address(uint160(user));
            payableUser.transfer(amount);
        } else {
            SafeERC20.safeTransfer(asset, user, amount);
        }

        transferOut(state, asset, BalancePath.getCommonPath(user), amount);

        Events.logWithdraw(user, asset, amount);
    }

    // Get a user's asset balance
    function balanceOf(
        Store.State storage state,
        Types.BalancePath memory balancePath,
        address asset
    )
        internal
        view
        returns (uint256)
    {
        mapping(address => uint256) storage balances = balancePath.getBalances(state);
        return balances[asset];
    }

    // Move asset from a balances map to another
    function transfer(
        Store.State storage state,
        address asset,
        Types.BalancePath memory fromBalancePath,
        Types.BalancePath memory toBalancePath,
        uint256 amount
    )
        internal
    {

        Requires.requirePathMarketIDAssetMatch(state, fromBalancePath, asset);
        Requires.requirePathMarketIDAssetMatch(state, toBalancePath, asset);

        mapping(address => uint256) storage fromBalances = fromBalancePath.getBalances(state);
        mapping(address => uint256) storage toBalances = toBalancePath.getBalances(state);

        require(fromBalances[asset] >= amount, "TRANSFER_BALANCE_NOT_ENOUGH");

        fromBalances[asset] = fromBalances[asset] - amount;
        toBalances[asset] = toBalances[asset].add(amount);
    }

    function transferIn(
        Store.State storage state,
        address asset,
        Types.BalancePath memory path,
        uint256 amount
    )
        internal
    {
        mapping(address => uint256) storage balances = path.getBalances(state);
        balances[asset] = balances[asset].add(amount);
        state.cash[asset] = state.cash[asset].add(amount);
    }

    function transferOut(
        Store.State storage state,
        address asset,
        Types.BalancePath memory path,
        uint256 amount
    )
        internal
    {
        mapping(address => uint256) storage balances = path.getBalances(state);
        balances[asset] = balances[asset].sub(amount);
        state.cash[asset] = state.cash[asset].sub(amount);
    }
}