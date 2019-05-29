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

import "./lib/Ownable.sol";
// import "./funding/Consts.sol";


import "./lib/Types.sol";

contract Margin is Ownable {

    // struct types

    // struct BorrowingRequest {
    //     uint40 durations;
    //     uint16 maxInterestRate;
    //     address from;
    //     uint256 amount;
    // }

    // struct BorrowResponse {
    //     uint16 interestRate;
    //     uint40 deadline;
    //     address owner;
    //     uint256 amount;
    // }

    // an map to save used OpenMargeinRequest
    mapping(bytes32 => bool) usedRequests;

    struct BorrowingParams {
        // will borrow ${borrowAmount} ${borrowAsset} from a funding source
        address borrowAsset;
        uint256 borrowAmount;

        // the worst borrowing interest rate
        uint16 maxInterestRate;

        // the earliest expired time;
        uint16 minExpiredAt;
    }

    struct ExchangeParams {
        address contractAddress;

        // will exchange at least ${minExchangedAmount} of ${collateralAsset}
        uint256 minExchangedAmount;

        bytes data;
    }

    struct TransferParams {
        // will move your ${collateralAmount} ${collateralAsset} into collateral account
        address collateralAsset;
        uint256 collateralAmount;
    }

    // user sign this struct as his will to open an market
    // TODO tie spaces
    struct OpenMarginRequest {
        BorrowingParams borrowingParams;
        ExchangeParams exchangeParams;
        TransferParams transferParams;

        // trader
        address trader;
        // expire time
        uint40 expiredAt;
        // liquidation rate for the margin position
        uint16 liquidationRate;
        // nonce to make same content request to have a different hash
        bytes32 nonce;
    }

    // events


    // public functions

    function open(OpenMarginRequest memory openReq)
        public
    {
        transfer(openReq.trader, openReq.transferParams);
        Types.Loan memory loan = borrow(openReq.borrowingParams);
        exchange(openReq.exchangeParams);
        collateralize(loan);

        // requrei at least has borrow + minExchangedAmount in collateralAccount, and liquidity rate is ...
    }

    function close() public {
    }

    function get() public view {
    }

    // actions

    function transfer(address trader, TransferParams memory params) internal {
        // transfer funds from proxy to current contract
        depositTokenFor(params.collateralAsset, trader, params.collateralAmount);

        // TODO any require to check amount??
    }

    // borrow funds from a source, and move the funds into current contarct
    function borrow(BorrowingParams memory params) internal returns (Types.Loan memory) {
        Types.Loan memory loan = BorrowingSourceInterface(params.contractAddress).borrow(
            params.borrowAsset,
            params.borrowAmount,
            params.maxInterestRate,
            params.data
        );

        require(loan.interestRate <= params.maxInterestRate, "Interest Rate Not Match");

        // borrowAsset Balance after
        // asset borrowedAmount is enough
        return loan;
    }

    // current contract acts as a trader,
    function exchange(ExchangeParams memory params) internal {
        // collateral Asset Balance Before

        // TODO: what is the second param
        // TODO: support an interface ??
        (bool success,) = params.contractAddress.call(params.data);
        require(success, "exchange failed");

        // collateral Asset Balance after, slippage protect
        // asset minExchangedAmount > (diff balance)

        // TODO: two kinds of asset amount changes after the call
    }

    function collateralize(Types.Loan memory loan) internal {

    }
}