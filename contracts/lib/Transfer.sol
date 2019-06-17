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
import "../funding/CollateralAccounts.sol";

library Transfer {
    using SafeMath for uint256;
    using BalancePath for Types.BalancePath;

    /** @dev Transfer asset into current contract
      */
    function depositFor(
        Store.State storage state,
        address asset,
        address from,
        Types.BalancePath memory toBalancePath,
        uint256 amount
    )
        internal
    {
        if (asset != Consts.ETHEREUM_TOKEN_ADDRESS()) {
            SafeERC20.safeTransferFrom(asset, from, address(this), amount);
        } else {
            require(amount == msg.value, "MSG_VALUE_AND_AMOUNT_MISMATCH");
        }

        mapping(address => uint256) storage toBalances = toBalancePath.getBalances(state);
        toBalances[asset] = toBalances[asset].add(amount);
        Events.logDeposit(asset, from, toBalancePath, amount);
    }

    /** @dev Transfer asset out of current contract
      */
    function withdrawFrom(
        Store.State storage state,
        address asset,
        Types.BalancePath memory fromBalancePath,
        address payable to,
        uint256 amount
    )
        internal
    {
        mapping(address => uint256) storage fromBalances = fromBalancePath.getBalances(state);

        require(fromBalances[asset] >= amount, "BALANCE_NOT_ENOUGH");

        fromBalances[asset] = fromBalances[asset].sub(amount);

        if (asset == Consts.ETHEREUM_TOKEN_ADDRESS()) {
            to.transfer(amount);
        } else {
            SafeERC20.safeTransfer(asset, to, amount);
        }

        Events.logWithdraw(asset, fromBalancePath, to, amount);
    }

    /** @dev Get a user's asset balance
      */
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

    function validTransferOut(
        Store.State storage state,
        Types.BalancePath memory path,
        address asset,
        uint256 amount
    )
        internal
        view
    {
        if (path.category == Types.BalanceCategory.CollateralAccount) {
            uint256 transferableAmount = CollateralAccounts.getTransferableAmount(state, path.marketID, path.user, asset);

            if (transferableAmount < amount) {
                revert("NO_ENOUGH_TRANSFERABLE_AMOUNT");
            }
        }
    }

    function validTransferIn(
        Store.State storage state,
        Types.BalancePath memory path
    )
        internal
        view
    {
        if (path.category == Types.BalanceCategory.CollateralAccount) {
            Types.CollateralAccount storage account = state.accounts[path.user][path.marketID];
            if (account.status == Types.CollateralAccountStatus.Liquid) {
                revert("CAN_NOT_OPERATOR_LIQUIDATING_COLLATERAL_ACCOUNT");
            }
        }
    }

    /** @dev Invoking internal funds transfer.
      */
    function transferFrom(
        Store.State storage state,
        address asset,
        Types.BalancePath memory fromBalancePath,
        Types.BalancePath memory toBalancePath,
        uint256 amount
    )
        internal
    {
        validTransferOut(state, fromBalancePath, asset, amount);
        validTransferIn(state, toBalancePath);

        mapping(address => uint256) storage fromBalances = fromBalancePath.getBalances(state);
        mapping(address => uint256) storage toBalances = toBalancePath.getBalances(state);

        require(fromBalances[asset] >= amount, "TRANSFER_BALANCE_NOT_ENOUGH");

        fromBalances[asset] = fromBalances[asset].sub(amount);
        toBalances[asset] = toBalances[asset].add(amount);

        Events.logTransfer(asset, fromBalancePath, toBalancePath, amount);
    }

}