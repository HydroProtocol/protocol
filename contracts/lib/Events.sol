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
    event Deposit(address asset, address from, Types.WalletPath toPath, uint256 amount);

    function logDeposit(address asset, address from, Types.WalletPath memory toPath, uint256 amount) internal {
        emit Deposit(asset, from, toPath, amount);
    }

    // some assets move out of contract
    event Withdraw(address asset, Types.WalletPath fromPath, address to, uint256 amount);

    function logWithdraw(address asset, Types.WalletPath memory fromPath, address to, uint256 amount) internal {
        emit Withdraw(asset, fromPath, to, amount);
    }

    // internal assets movement
    event Transfer(address asset, Types.WalletPath fromPath, Types.WalletPath toPath, uint256 amount);

    function logTransfer(address asset, Types.WalletPath memory fromPath, Types.WalletPath memory toPath, uint256 amount) internal {
        emit Transfer(asset, fromPath, toPath, amount);
    }

    ///////////////////
    // Admin Actions //
    ///////////////////

    event MarketCreate(Types.Market asset);

    function logMarketCreate(Types.Market memory market) internal {
        emit MarketCreate(market);
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
        Types.OrderAddressSet addressSet,
        address maker,
        address taker,
        address buyer,
        uint256 makerFee,
        uint256 makerRebate,
        uint256 takerFee,
        uint256 makerGasFee,
        uint256 takerGasFee,
        uint256 baseTokenFilledAmount,
        uint256 quoteTokenFilledAmount
    );

    function logExchangeMatch(Types.MatchResult memory result, Types.OrderAddressSet memory addressSet) internal {
        emit ExchangeMatch(
            addressSet,
            result.maker,
            result.taker,
            result.buyer,
            result.makerFee,
            result.makerRebate,
            result.takerFee,
            result.makerGasFee,
            result.takerGasFee,
            result.baseTokenFilledAmount,
            result.quoteTokenFilledAmount
        );
    }

    event OrderCancel(bytes32 indexed orderHash);

    function logOrderCancel(bytes32 orderHash) internal {
        emit OrderCancel(orderHash);
    }
}