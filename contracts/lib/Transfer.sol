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

library Transfer {
    using SafeMath for uint256;

    /** @dev deposit asset
      * @param assetID ID of asset to transfer.
      * @param amount  Amount of asset to transfer.
      */
    function deposit(
        Store.State storage state,
        uint16 assetID,
        uint256 amount
    )
        internal
    {
        depositFor(state, assetID, msg.sender, msg.sender, amount);
    }

    /** @dev Transfer asset into current contract
      * @param assetID ID of asset to transfer.
      * @param from    Address of asset owner.
      * @param to      Address of the receiver.
      * @param amount  Amount of asset to transfer.
      */
    function depositFor(
        Store.State storage state,
        uint16 assetID,
        address from,
        address to,
        uint256 amount
    )
        internal
    {
        if (amount == 0) {
            return;
        }

        Types.Asset storage asset = state.assets[assetID];

        if (asset.tokenAddress != Consts.ETHEREUM_TOKEN_ADDRESS()) {
            SafeERC20.safeTransferFrom(asset.tokenAddress, from, address(this), amount);
        } else {
            require(amount == msg.value, "Wrong amount");
        }

        state.balances[to][assetID] = state.balances[to][assetID].add(amount);
        Events.logDeposit(assetID, from, to, amount);
    }

    /** @dev withdraw asset
      * @param asset   Address of asset to transfer.
      * @param amount  Amount of asset to transfer.
      */
    function withdraw(
        Store.State storage state,
        uint16 asset,
        uint256 amount
    ) internal {
        withdrawTo(state, asset, msg.sender, msg.sender, amount);
    }

    /** @dev Transfer asset out of current contract
      * @param assetID ID of asset to transfer.
      * @param from    Address of asset owner.
      * @param to      Address of the receiver.
      * @param amount  Amount of asset to transfer.
      */
    function withdrawTo(
        Store.State storage state,
        uint16 assetID,
        address from,
        address payable to,
        uint256 amount
    )
        internal
    {
        if (amount == 0) {
            return;
        }

        require(state.balances[from][assetID] >= amount, "BALANCE_NOT_ENOUGH");

        Types.Asset storage asset = state.assets[assetID];

        state.balances[from][assetID] = state.balances[from][assetID].sub(amount);

        if (asset.tokenAddress == Consts.ETHEREUM_TOKEN_ADDRESS()) {
            to.transfer(amount);
        } else {
            SafeERC20.safeTransfer(asset.tokenAddress, to, amount);
        }

        Events.logWithdraw(assetID, from, to, amount);
    }

    /** @dev Get a user's asset balance
      * @param assetID  ID of asset
      * @param user     Address of user
      */
    function balanceOf(
        Store.State storage state,
        uint16 assetID,
        address user
    )
        internal
        view
        returns (uint256)
    {
        return state.balances[user][assetID];
    }

    /** @dev Invoking internal funds transfer.
      * @param assetID ID of asset to transfer.
      * @param from    Address to transfer asset from.
      * @param to      Address to transfer asset to.
      * @param amount  Amount of asset to transfer.
      */
    function transferFrom(
        Store.State storage state,
        uint16 assetID,
        address from,
        address to,
        uint256 amount
    )
        internal
    {
        // do nothing when amount is zero
        if (amount == 0) {
            return;
        }

        require(state.balances[from][assetID] >= amount, "TRANSFER_BALANCE_NOT_ENOUGH");

        state.balances[from][assetID] = state.balances[from][assetID].sub(amount);
        state.balances[to][assetID] = state.balances[to][assetID].add(amount);

        Events.logTransfer(assetID, from, to, amount);
    }
}