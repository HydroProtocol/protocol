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
    {
        if (asset != Consts.ETHEREUM_TOKEN_ADDRESS()) {
            SafeERC20.safeTransferFrom(asset, msg.sender, address(this), amount);
        } else {
            require(amount == msg.value, "MSG_VALUE_AND_AMOUNT_MISMATCH");
        }

        state.balances[msg.sender][asset] = state.balances[msg.sender][asset].add(amount);

        state.cash[asset] = state.cash[asset].add(amount);
        Events.logDeposit(msg.sender, asset, amount);
    }

    // Transfer asset out of current contract
    function withdraw(
        Store.State storage state,
        address asset,
        uint256 amount
    )
        internal
    {
       require(state.balances[msg.sender][asset] >= amount, "BALANCE_NOT_ENOUGH");

        state.balances[msg.sender][asset] = state.balances[msg.sender][asset] - amount;

        if (asset == Consts.ETHEREUM_TOKEN_ADDRESS()) {
            msg.sender.transfer(amount);
        } else {
            SafeERC20.safeTransfer(asset, msg.sender, amount);
        }

        state.cash[asset] = state.cash[asset].sub(amount);

        Events.logWithdraw(msg.sender, asset, amount);
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
        if (toBalancePath.category == Types.BalanceCategory.CollateralAccount) {
            Requires.requireMarketIDAndAssetMatch(state, toBalancePath.marketID, asset);
        }

        mapping(address => uint256) storage fromBalances = fromBalancePath.getBalances(state);
        mapping(address => uint256) storage toBalances = toBalancePath.getBalances(state);

        // TODO, save from balance before to save gas
        require(fromBalances[asset] >= amount, "TRANSFER_BALANCE_NOT_ENOUGH");

        fromBalances[asset] = fromBalances[asset] - amount;
        toBalances[asset] = toBalances[asset].add(amount);
    }
}