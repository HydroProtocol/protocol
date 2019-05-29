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

import { Types } from "./Types.sol";

library Events {
    // some assets move into contract
    event Deposit(address asset, address from, address to, uint256 amount);

    function logDeposit(address asset, address from, address to, uint256 amount) internal {
        emit Deposit(asset, from, to, amount);
    }

    // some assets move out of contract
    event Withdraw(address asset, address from, address to, uint256 amount);

    function logWithdraw(address asset, address from, address to, uint256 amount) internal {
        emit Withdraw(asset, from, to, amount);
    }

    // internal assets movement
    event Transfer(address asset, address from, address to, uint256 amount);

    function logTransfer(address asset, address from, address to, uint256 amount) internal {
        emit Transfer(asset, from, to, amount);
    }

    event AssetCreate(Types.Asset asset);

    function logAssetCreate(Types.Asset memory asset) internal {
        emit AssetCreate(asset);
    }

    // a user deposit tokens to default collateral account
    event DepositCollateral(address token, address user, uint256 amount);

    function logDepositCollateral(address token, address user, uint256 amount) internal {
        emit DepositCollateral(token, user, amount);
    }

    // a user withdraw tokens from default collateral account
    event WithdrawCollateral(address token, address user, uint256 amount);

    function logWithdrawCollateral(address token, address user, uint256 amount) internal {
        emit WithdrawCollateral(token, user, amount);
    }

    // an auction is created
    event AuctionCreate(uint256 auctionID);

    function logAuctionCreate(uint256 auctionID) internal {
        emit AuctionCreate(auctionID);
    }

    // a user filled an acution
    event FillAuction(uint256 auctionID, uint256 filledAmount);

    function logFillAuction(uint256 auctionID, uint256 filledAmount) internal {
        emit FillAuction(auctionID, filledAmount);
    }

    // an auction is finished
    event AuctionFinished(uint256 auctionID);

    function logAuctionFinished(uint256 auctionID) internal {
        emit AuctionFinished(auctionID);
    }
}