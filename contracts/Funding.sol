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

contract Funding is Assets, Orders, Loans {

    mapping(address => uint256) inLiquidation;

    constructor() public {
    }

    function matchOrders(
        Order[] memory makerOrders,
        Order memory takerOrder,
        uint256[] memory filledAmount
    ) public {

        require(isOrderValid(takerOrder));
        require(makerOrders.length==filledAmount.length);

        for (uint256 i = 0; i < makerOrders.length; i++) {

            Order memory makerOrder = makerOrders[i];
            require(isOrderValid(makerOrder));

            if (isLenderOrder(makerOrder.data)) {
                matchSingleOrderInternal(
                    makerOrder,
                    takerOrder,
                    filledAmount[i],
                    getInterestRate(makerOrder)
                );
            } else {
                matchSingleOrderInternal(
                    takerOrder,
                    makerOrder,
                    filledAmount[i],
                    getInterestRate(makerOrder)
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

        require(borrower != lender);

        // check asset
        require(lenderOrder.asset == borrowerOrder.asset);

        // check relayer
        require(lenderOrder.relayer == borrowerOrder.relayer);
        require(msg.sender == lenderOrder.relayer);

        // check executeInterest
        require(executeInterest >= getInterestRate(lenderOrder));
        require(executeInterest <= getInterestRate(borrowerOrder));

        // check amount
        bytes32 borrowerOrderId = hashOrder(borrowerOrder);
        require(amount <= borrowerOrder.amount - orderInfos[borrowerOrderId].filledAmount);
        bytes32 lenderOrderId = hashOrder(lenderOrder);
        require(amount <= lenderOrder.amount - orderInfos[lenderOrderId].filledAmount);

        // check loan duration
        uint256 lenderDuration;
        if (block.timestamp + getLoanDuration(lenderOrder) < getExpiredAt(lenderOrder)){
            lenderDuration = getLoanDuration(lenderOrder);
        } else {
            lenderDuration = getExpiredAt(lenderOrder) - block.timestamp;
        }
        require(lenderDuration >= getLoanDuration(borrowerOrder));

        // new loan
        Loan storage newLoan = Loan(
            lenderOrderId,
            lender,
            borrower,
            lenderOrder.asset,
            amount,
            executeInterest,
            block.timestamp,
            lenderDuration
        );
        recordNewLoan(newLoan);

        // change filled amount
        orderInfos[lenderOrderId].filledAmount += amount;
        orderInfos[borrowerOrderId].filledAmount += amount;

        // borrower 
        require(isUserRepayable(borrower));

        // settle assets
        vault.transferCash(lenderOrder.asset, lender, borrower, amount);
    }

    function cancel(Order memory order) {
        require(msg.sender == order.owner);
        bytes32 orderId = hashOrder(order);
        orderInfos[orderId].canceled = true;
    }

    function repay(bytes32 loanId, uint256 amount) {
        Loan memory loan = loansById[loanId];

        // must be sent by borrower
        require(msg.sender == loan.borrower);

        // require amount less than loan amount
        require(amount <= loan.amount);

        // calculate interest
        (uint256 totalInterest, uint256 relayerFee) = calculateLoanInterest(loanId, amount);
        uint256 lenderInterest = totalInterest - relayerFee;

        // settle assets
        vault.transferCash(loan.asset, loan.borrower, loan.lender, amount+lenderInterest);
        vault.transferCash(loan.asset, loan.borrower, loan.relayer, relayerFee);

        // change loan info
        reduceLoan(loanId, amount);
    }

}