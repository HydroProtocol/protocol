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

library Transfer {
    using SafeMath for uint256;
    using WalletPath for Types.WalletPath;

    /** @dev Transfer asset into current contract
      */
    function depositFor(
        Store.State storage state,
        address asset,
        address from,
        Types.WalletPath memory toWalletPath,
        uint256 amount
    )
        internal
    {
        if (asset != Consts.ETHEREUM_TOKEN_ADDRESS()) {
            SafeERC20.safeTransferFrom(asset, from, address(this), amount);
        } else {
            require(amount == msg.value, "MSG_VALUE_AND_AMOUNT_MISMATCH");
        }

        Types.Wallet storage toWallet = toWalletPath.getWallet(state);
        toWallet.balances[asset] = toWallet.balances[asset].add(amount);
        Events.logDeposit(asset, from, toWalletPath, amount);
    }

    /** @dev Transfer asset out of current contract
      */
    function withdrawFrom(
        Store.State storage state,
        address asset,
        Types.WalletPath memory fromWalletPath,
        address payable to,
        uint256 amount
    )
        internal
    {
        Types.Wallet storage fromWallet = fromWalletPath.getWallet(state);

        require(fromWallet.balances[asset] >= amount, "BALANCE_NOT_ENOUGH");

        fromWallet.balances[asset] = fromWallet.balances[asset].sub(amount);

        if (asset == Consts.ETHEREUM_TOKEN_ADDRESS()) {
            to.transfer(amount);
        } else {
            SafeERC20.safeTransfer(asset, to, amount);
        }

        Events.logWithdraw(asset, fromWalletPath, to, amount);
    }

    /** @dev Get a user's asset balance
      */
    function balanceOf(
        Store.State storage state,
        Types.WalletPath memory walletPath,
        address asset
    )
        internal
        view
        returns (uint256)
    {
        Types.Wallet storage wallet = walletPath.getWallet(state);
        return wallet.balances[asset];
    }

    /** @dev Invoking internal funds transfer.
      */
    function transferFrom(
        Store.State storage state,
        address asset,
        Types.WalletPath memory fromWalletPath,
        Types.WalletPath memory toWalletPath,
        uint256 amount
    )
        internal
    {
        Types.Wallet storage fromWallet = fromWalletPath.getWallet(state);
        Types.Wallet storage toWallet = toWalletPath.getWallet(state);

        require(fromWallet.balances[asset] >= amount, "TRANSFER_BALANCE_NOT_ENOUGH");

        fromWallet.balances[asset] = fromWallet.balances[asset].sub(amount);
        toWallet.balances[asset] = toWallet.balances[asset].add(amount);

        Events.logTransfer(asset, fromWalletPath, toWalletPath, amount);
    }

}