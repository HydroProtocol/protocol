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

pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "./funding/Assets.sol";
import "./funding/Orders.sol";
import "./funding/Loans.sol";
import "./funding/Auction.sol";
import "./funding/Collateral.sol";
import "./funding/ProxyCaller.sol";
import "./funding/OracleCaller.sol";

contract Funding is Orders, Auction {

    mapping(address => uint256) inLiquidation;

    constructor(address _proxyAddress, address _oracleAddress)
        ProxyCaller(_proxyAddress)
        OracleCaller(_oracleAddress)
        public
    {}

    function matchOrders(
        Order memory takerOrder,
        Order[] memory makerOrders,
        uint256[] memory filledAmounts
    ) public {

    //     require(isOrderValid(takerOrder));
        require(makerOrders.length == filledAmounts.length, "MAKER_ORDERS_AND_FILLED_AMOUNTS_MISMATCH");

        for (uint256 i = 0; i < makerOrders.length; i++) {

            Order memory makerOrder = makerOrders[i];
    //         require(isOrderValid(makerOrder));

            if (isLenderOrder(makerOrder.data)) {
                matchSingleOrderInternal(
                    makerOrder,
                    takerOrder,
                    filledAmounts[i],
                    0 // getInterestRate(makerOrder)
                );
            } else {
                matchSingleOrderInternal(
                    takerOrder,
                    makerOrder,
                    filledAmounts[i],
                    0 // getInterestRate(makerOrder)
                );
            }
        }
    }

    function matchSingleOrderInternal(
        Order memory lenderOrder,
        Order memory borrowerOrder,
        uint256 amount,
        uint256 executeInterest
    ) internal {
        address borrower = borrowerOrder.owner;
        address lender = lenderOrder.owner;

        require(borrower != lender, "CAN_NOT_MATCH_SAME_USER_ORDERS");

        // check asset
        require(lenderOrder.asset == borrowerOrder.asset, "ASSET_MISMATCH");

        // check relayer
        require(lenderOrder.relayer == borrowerOrder.relayer, "RELAYER_MISMATCH");
        require(msg.sender == lenderOrder.relayer, "INVALID_SENDER"); // use sender logic

        // check executeInterest
        // require(executeInterest >= getInterestRate(lenderOrder));
        // require(executeInterest <= getInterestRate(borrowerOrder));

        // check amount
        bytes32 borrowerOrderHash = getOrderHash(borrowerOrder);
        // require(amount <= borrowerOrder.amount - orderInfos[borrowerOrderId].filledAmount);
        bytes32 lenderOrderHash = getOrderHash(lenderOrder);
        // require(amount <= lenderOrder.amount - orderInfos[lenderOrderId].filledAmount);

        // check loan duration
        uint40 lenderDuration;
        // if (block.timestamp + getLoanDuration(lenderOrder) < getExpiredAt(lenderOrder)){
        //     lenderDuration = getLoanDuration(lenderOrder);
        // } else {
        //     lenderDuration = getExpiredAt(lenderOrder) - block.timestamp;
        // }
        // require(lenderDuration >= getLoanDuration(borrowerOrder));

        // new loan
        Loan memory newLoan = Loan(
            0,
            lenderOrderHash,
            lenderOrder.owner,
            borrowerOrder.owner,
            borrowerOrder.relayer,
            lenderOrder.asset,
            amount,
            uint16(executeInterest),
            uint40(block.timestamp),
            lenderDuration,
            0,
            0
        );

        createLoan(newLoan);

        // TODO use a match result
        // settle loan, transfer asset,
        transferFrom(borrowerOrder.asset, lenderOrder.owner, borrowerOrder.owner, amount);

        // change filled amount
        orderFilledAmount[borrowerOrderHash] = orderFilledAmount[borrowerOrderHash].add(amount);
        orderFilledAmount[lenderOrderHash] = orderFilledAmount[lenderOrderHash].add(amount);

    //     // borrower
    //     require(isUserRepayable(borrower));
    }

    // function cancel(Order memory order) {
    //     require(msg.sender == order.owner);
    //     bytes32 orderId = hashOrder(order);
    //     orderInfos[orderId].canceled = true;
    // }

    // function repay(bytes32 loanId, uint256 amount) {
    //     Loan memory loan = loansById[loanId];

    //     // must be sent by borrower
    //     require(msg.sender == loan.borrower);

    //     // require amount less than loan amount
    //     require(amount <= loan.amount);

    //     // calculate interest
    //     (uint256 totalInterest, uint256 relayerFee) = calculateLoanInterest(loanId, amount);
    //     uint256 lenderInterest = totalInterest - relayerFee;

    //     // settle assets
    //     vault.transferCash(loan.asset, loan.borrower, loan.lender, amount+lenderInterest);
    //     vault.transferCash(loan.asset, loan.borrower, loan.relayer, relayerFee);

    //     // change loan info
    //     reduceLoan(loanId, amount);
    // }

}