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

import "./Pool.sol";

import "../lib/Store.sol";
import "../lib/Transfer.sol";

/**
 * A library allows user to do multi actions at once in a single transaction.
 */
library BatchActions {

    /**
     * All actions can be included in a batch
     */
    enum ActionType {
        Deposit,   // Move asset from your wallet to tradeable balance
        Withdraw,  // Move asset from your tradeable balance to wallet
        Transfer,  // Move asset between tradeable balance and margin account
        Borrow,    // Borrow asset from pool
        Repay,     // Repay asset to pool
        Supply,    // Move asset from tradeable balance to pool to earn interest
        Unsupply   // Move asset from pool back to tradeable balance
    }

    /**
     * Uniform parameter for an action
     */
    struct Action {
        ActionType actionType;  // The action type
        bytes encodedParams;    // Encoded params, it's different for each action
    }

    /**
     * Batch actions entrance
     * @param actions List of actions
     */
    function batch(
        Store.State storage state,
        Action[] memory actions
    )
        internal
    {
        for (uint256 i = 0; i < actions.length; i++) {
            Action memory action = actions[i];
            ActionType actionType = action.actionType;

            if (actionType == ActionType.Deposit) {
                deposit(state, action);
            } else if (actionType == ActionType.Withdraw) {
                withdraw(state, action);
            } else if (actionType == ActionType.Transfer) {
                transfer(state, action);
            } else if (actionType == ActionType.Borrow) {
                borrow(state, action);
            } else if (actionType == ActionType.Repay) {
                repay(state, action);
            } else if (actionType == ActionType.Supply) {
                supply(state, action);
            } else if (actionType == ActionType.Unsupply) {
                unsupply(state, action);
            }
        }
    }

    function deposit(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (address asset, uint256 amount) = abi.decode(action.encodedParams, (address, uint256));
        Transfer.depositFor(state, asset, msg.sender, BalancePath.getCommonPath(msg.sender), amount);
    }

    function withdraw(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (address asset, uint256 amount) = abi.decode(action.encodedParams, (address, uint256));
        Transfer.withdrawFrom(state, asset, BalancePath.getCommonPath(msg.sender), msg.sender, amount);
    }

    function transfer(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (
            address asset,
            Types.BalancePath memory fromBalancePath,
            Types.BalancePath memory toBalancePath,
            uint256 amount
        ) = abi.decode(action.encodedParams, (address, Types.BalancePath, Types.BalancePath, uint256));

        require(fromBalancePath.user == msg.sender, "CAN_NOT_MOVE_OTHERS_ASSET");
        require(toBalancePath.user == msg.sender, "CAN_NOT_MOVE_ASSET_TO_OTHER");

        Transfer.transferFrom(state, asset, fromBalancePath, toBalancePath, amount);
    }

    function borrow(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (
            uint16 marketID,
            address asset,
            uint256 amount
        ) = abi.decode(action.encodedParams, (uint16, address, uint256));

        Pool.borrow(state, msg.sender, marketID, asset, amount);
    }

    function repay(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (
            uint16 marketID,
            address asset,
            uint256 amount
        ) = abi.decode(action.encodedParams, (uint16, address, uint256));

        Pool.repay(state, msg.sender, marketID, asset, amount);
    }

    function supply(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (
            address asset,
            uint256 amount
        ) = abi.decode(action.encodedParams, (address, uint256));

        Pool.supply(state, asset, amount, msg.sender);
    }

    function unsupply(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (
            address asset,
            uint256 amount
        ) = abi.decode(action.encodedParams, (address, uint256));

        Pool.withdraw(state, asset, amount, msg.sender);
    }
}