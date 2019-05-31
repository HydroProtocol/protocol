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
    //////////////////
    // Funds moving //
    //////////////////

    // some assets move into contract
    event Deposit(uint16 assetID, address from, address to, uint256 amount);

    function logDeposit(uint16 assetID, address from, address to, uint256 amount) internal {
        emit Deposit(assetID, from, to, amount);
    }

    // some assets move out of contract
    event Withdraw(uint16 assetID, address from, address to, uint256 amount);

    function logWithdraw(uint16 assetID, address from, address to, uint256 amount) internal {
        emit Withdraw(assetID, from, to, amount);
    }

    // internal assets movement
    event Transfer(uint16 assetID, address from, address to, uint256 amount);

    function logTransfer(uint16 assetID, address from, address to, uint256 amount) internal {
        emit Transfer(assetID, from, to, amount);
    }

    // a user deposit tokens to default collateral account
    event DepositCollateral(uint16 assetID, address user, uint256 amount);

    function logDepositCollateral(uint16 assetID, address user, uint256 amount) internal {
        emit DepositCollateral(assetID, user, amount);
    }

    // a user withdraw tokens from default collateral account
    event WithdrawCollateral(uint16 assetID, address user, uint256 amount);

    function logWithdrawCollateral(uint16 assetID, address user, uint256 amount) internal {
        emit WithdrawCollateral(assetID, user, amount);
    }

    ///////////////////
    // Admin Actions //
    ///////////////////

    event AssetCreate(Types.Asset asset);

    function logAssetCreate(Types.Asset memory asset) internal {
        emit AssetCreate(asset);
    }

    event DiscountConfigChange(bytes32 newConfig);

    function logDiscountConfigChange(bytes32 newConfig) internal {
        emit DiscountConfigChange(newConfig);
    }

    /////////////
    // Auction //
    /////////////

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

    //////////
    // Loan //
    //////////

    event LoanCreate(uint256 loanID);

    function logLoanCreate(uint256 loanID) internal {
        emit LoanCreate(loanID);
    }

    /////////////
    // Relayer //
    /////////////

    event RelayerApproveDelegate(address indexed relayer, address indexed delegate);

    function logRelayerApproveDelegate(address relayer, address delegate) internal {
        emit RelayerApproveDelegate(relayer, delegate);
    }

    event RelayerRevokeDelegate(address indexed relayer, address indexed delegate);

    function logRelayerRevokeDelegate(address relayer, address delegate) internal {
        emit RelayerRevokeDelegate(relayer, delegate);
    }

    event RelayerExit(address indexed relayer);

    function logRelayerExit(address relayer) internal {
        emit RelayerExit(relayer);
    }

    event RelayerJoin(address indexed relayer);

    function logRelayerJoin(address relayer) internal {
        emit RelayerJoin(relayer);
    }

    //////////////
    // Exchange //
    //////////////

    event ExchangeMatch(
        Types.ExchangeOrderAddressSet addressSet,
        Types.ExchangeMatchResult result
    );

    function logExchangeMatch(Types.ExchangeMatchResult memory result, Types.ExchangeOrderAddressSet memory addressSet) internal {
        emit ExchangeMatch(addressSet, result);
    }
}