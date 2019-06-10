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

import "./Store.sol";
import "./Transfer.sol";

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
}