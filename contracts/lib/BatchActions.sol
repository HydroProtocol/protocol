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

pragma solidity ^0.5.8;
pragma experimental ABIEncoderV2;

import "./Store.sol";
import "./Transfer.sol";
import "../funding/Pool.sol";

library BatchActions {
    enum ActionType {
        Deposit,
        Withdraw,
        Transfer,
        Borrow,
        Repay,
        Supply,
        Unsupply
    }

    struct Action {
        ActionType actionType;
        bytes encodedParams;
    }

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
        Transfer.depositFor(state, asset, msg.sender, WalletPath.getBalancePath(msg.sender), amount);
    }

    function withdraw(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (address asset, uint256 amount) = abi.decode(action.encodedParams, (address, uint256));
        Transfer.withdrawFrom(state, asset, WalletPath.getBalancePath(msg.sender), msg.sender, amount);
    }

    function transfer(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (
            address asset,
            Types.WalletPath memory fromWalletPath,
            Types.WalletPath memory toWalletPath,
            uint256 amount
        ) = abi.decode(action.encodedParams, (address, Types.WalletPath, Types.WalletPath, uint256));

        require(fromWalletPath.user == msg.sender, "CAN_NOT_MOVE_OTHERS_ASSET");
        require(toWalletPath.user == msg.sender, "CAN_NOT_MOVE_ASSET_TO_OTHER");

        Transfer.transferFrom(state, asset, fromWalletPath, toWalletPath, amount);
    }

    function borrow(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (
            address user,
            uint16 marketID,
            address asset,
            uint256 amount
        ) = abi.decode(action.encodedParams, (address, uint16, address, uint256));

        Pool.borrow(state, user, marketID, asset, amount);
    }

    function repay(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (
            address user,
            uint16 marketID,
            address asset,
            uint256 amount
        ) = abi.decode(action.encodedParams, (address, uint16, address, uint256));

        Pool.repay(state, user, marketID, asset, amount);
    }

    function supply(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (
            address asset,
            uint256 amount,
            address user
        ) = abi.decode(action.encodedParams, (address, uint256, address));

        Pool.supply(state, asset, amount, user);
    }

    function unsupply(
        Store.State storage state,
        Action memory action
    )
        internal
    {
        (
            address asset,
            uint256 amount,
            address user
        ) = abi.decode(action.encodedParams, (address, uint256, address));

        Pool.withdraw(state, asset, amount, user);
    }
}