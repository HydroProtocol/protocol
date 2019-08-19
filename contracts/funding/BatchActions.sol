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

import "./LendingPool.sol";

import "../lib/Store.sol";
import "../lib/SafeMath.sol";
import "../lib/Requires.sol";
import "../lib/Transfer.sol";
import "../lib/Events.sol";

/**
 * Library to allow executing multiple actions at once in a single transaction.
 */
library BatchActions {
    using SafeMath for uint256;
    /**
     * All allowed actions types
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
        Action[] memory actions,
        uint256 msgValue
    )
        public
    {
        uint256 totalDepositedEtherAmount = 0;

        for (uint256 i = 0; i < actions.length; i++) {
            Action memory action = actions[i];
            ActionType actionType = action.actionType;

            if (actionType == ActionType.Deposit) {
                uint256 depositedEtherAmount = deposit(state, action);
                totalDepositedEtherAmount = totalDepositedEtherAmount.add(depositedEtherAmount);
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

        require(totalDepositedEtherAmount == msgValue, "MSG_VALUE_AND_AMOUNT_MISMATCH");
    }

    function deposit(
        Store.State storage state,
        Action memory action
    )
        private
        returns (uint256)
    {
        (
            address asset,
            uint256 amount
        ) = abi.decode(
            action.encodedParams,
            (
                address,
                uint256
            )
        );

        return Transfer.deposit(
            state,
            asset,
            amount
        );
    }

    function withdraw(
        Store.State storage state,
        Action memory action
    )
        private
    {
        (
            address asset,
            uint256 amount
        ) = abi.decode(
            action.encodedParams,
            (
                address,
                uint256
            )
        );

        Transfer.withdraw(
            state,
            msg.sender,
            asset,
            amount
        );
    }

    function transfer(
        Store.State storage state,
        Action memory action
    )
        private
    {
        (
            address asset,
            Types.BalancePath memory fromBalancePath,
            Types.BalancePath memory toBalancePath,
            uint256 amount
        ) = abi.decode(
            action.encodedParams,
            (
                address,
                Types.BalancePath,
                Types.BalancePath,
                uint256
            )
        );

        require(fromBalancePath.user == msg.sender, "CAN_NOT_MOVE_OTHER_USER_ASSET");
        require(toBalancePath.user == msg.sender, "CAN_NOT_MOVE_ASSET_TO_OTHER_USER");

        Requires.requirePathNormalStatus(state, fromBalancePath);
        Requires.requirePathNormalStatus(state, toBalancePath);

        // The below two requires will be checked in Transfer.transfer
        // Requires.requirePathMarketIDAssetMatch(state, fromBalancePath, asset);
        // Requires.requirePathMarketIDAssetMatch(state, toBalancePath, asset);

        if (fromBalancePath.category == Types.BalanceCategory.CollateralAccount) {
            require(
                CollateralAccounts.getTransferableAmount(state, fromBalancePath.marketID, fromBalancePath.user, asset) >= amount,
                "COLLATERAL_ACCOUNT_TRANSFERABLE_AMOUNT_NOT_ENOUGH"
            );
        }

        Transfer.transfer(
            state,
            asset,
            fromBalancePath,
            toBalancePath,
            amount
        );

        if (toBalancePath.category == Types.BalanceCategory.CollateralAccount) {
            Events.logIncreaseCollateral(msg.sender, toBalancePath.marketID, asset, amount);
        }
        if (fromBalancePath.category == Types.BalanceCategory.CollateralAccount) {
            Events.logDecreaseCollateral(msg.sender, fromBalancePath.marketID, asset, amount);
        }
    }

    function borrow(
        Store.State storage state,
        Action memory action
    )
        private
    {
        (
            uint16 marketID,
            address asset,
            uint256 amount
        ) = abi.decode(
            action.encodedParams,
            (
                uint16,
                address,
                uint256
            )
        );

        Requires.requireMarketIDExist(state, marketID);
        Requires.requireMarketBorrowEnabled(state, marketID);
        Requires.requireMarketIDAndAssetMatch(state, marketID, asset);
        Requires.requireAccountNormal(state, marketID, msg.sender);
        LendingPool.borrow(
            state,
            msg.sender,
            marketID,
            asset,
            amount
        );
    }

    function repay(
        Store.State storage state,
        Action memory action
    )
        private
    {
        (
            uint16 marketID,
            address asset,
            uint256 amount
        ) = abi.decode(
            action.encodedParams,
            (
                uint16,
                address,
                uint256
            )
        );

        Requires.requireMarketIDExist(state, marketID);
        Requires.requireMarketIDAndAssetMatch(state, marketID, asset);

        LendingPool.repay(
            state,
            msg.sender,
            marketID,
            asset,
            amount
        );
    }

    function supply(
        Store.State storage state,
        Action memory action
    )
        private
    {
        (
            address asset,
            uint256 amount
        ) = abi.decode(
            action.encodedParams,
            (
                address,
                uint256
            )
        );

        Requires.requireAssetExist(state, asset);
        LendingPool.supply(
            state,
            asset,
            amount,
            msg.sender
        );
    }

    function unsupply(
        Store.State storage state,
        Action memory action
    )
        private
    {
        (
            address asset,
            uint256 amount
        ) = abi.decode(
            action.encodedParams,
            (
                address,
                uint256
            )
        );

        Requires.requireAssetExist(state, asset);
        LendingPool.unsupply(
            state,
            asset,
            amount,
            msg.sender
        );
    }
}