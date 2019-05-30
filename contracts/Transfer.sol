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
import "./lib/Consts.sol";

contract Transfer is GlobalStore {
    using SafeMath for uint256;

    /** @dev deposit asset
      * @param asset   Address of asset to transfer.
      * @param amount  Amount of asset to transfer.
      */
    function deposit(uint16 asset, uint256 amount) public payable {
        depositFor(asset, msg.sender, msg.sender, amount);
    }

    /** @dev Transfer asset into current contract
      * @param assetID ID of asset to transfer.
      * @param from    Address of asset owner.
      * @param to      Address of the receiver.
      * @param amount  Amount of asset to transfer.
      */
    function depositFor(uint16 assetID, address from, address to, uint256 amount) public payable {
        if (amount == 0) {
            return;
        }

        Types.Asset storage asset = state.assets[assetID];

        if (asset.tokenAddress != Consts.ETHEREUM_TOKEN_ADDRESS()) {
            SafeERC20.safeTransferFrom(asset.tokenAddress, from, address(this), amount);
        } else {
            require(amount == msg.value, "Wrong amount");
        }

        state.balances[assetID][to] = state.balances[assetID][to].add(amount);
        Events.logDeposit(assetID, from, to, amount);
    }

    /** @dev withdraw asset
      * @param asset   Address of asset to transfer.
      * @param amount  Amount of asset to transfer.
      */
    function withdraw(uint16 asset, uint256 amount) public {
        withdrawTo(asset, msg.sender, msg.sender, amount);
    }

    /** @dev Transfer asset out of current contract
      * @param assetID ID of asset to transfer.
      * @param from    Address of asset owner.
      * @param to      Address of the receiver.
      * @param amount  Amount of asset to transfer.
      */
    function withdrawTo(uint16 assetID, address from, address payable to, uint256 amount) public {
        if (amount == 0) {
            return;
        }

        require(state.balances[assetID][from] >= amount, "BALANCE_NOT_ENOUGH");

        Types.Asset storage asset = state.assets[assetID];

        state.balances[assetID][from] = state.balances[assetID][from].sub(amount);

        if (asset.tokenAddress == Consts.ETHEREUM_TOKEN_ADDRESS()) {
            to.transfer(amount);
        } else {
            SafeERC20.safeTransfer(asset.tokenAddress, to, amount);
        }

        Events.logWithdraw(assetID, from, to, amount);
    }

    /** @dev fallback function to allow deposit ether into this contract */
    function () external payable {

        // deposit ${msg.value} ether for ${msg.sender}
        deposit(getAssetIDByAddress(Consts.ETHEREUM_TOKEN_ADDRESS()), msg.value);
    }

    /** @dev Get a user's asset balance
      * @param assetID  ID of asset
      * @param user     Address of user
      */
    function balanceOf(uint16 assetID, address user) public view returns (uint256) {
        return state.balances[assetID][user];
    }

    /** @dev Invoking internal funds transfer.
      * @param assetID ID of asset to transfer.
      * @param from    Address to transfer asset from.
      * @param to      Address to transfer asset to.
      * @param amount  Amount of asset to transfer.
      */
    function transferFrom(uint16 assetID, address from, address to, uint256 amount)
      internal
    {
        // do nothing when amount is zero
        if (amount == 0) {
            return;
        }

        require(state.balances[assetID][from] >= amount, "TRANSFER_BALANCE_NOT_ENOUGH");

        state.balances[assetID][from] = state.balances[assetID][from].sub(amount);
        state.balances[assetID][to] = state.balances[assetID][to].add(amount);

        Events.logTransfer(assetID, from, to, amount);
    }
}