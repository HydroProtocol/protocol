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

import "../GlobalStore.sol";
import "../Transfer.sol";

import "../helper/Debug.sol";

import "../lib/SafeMath.sol";
import "../lib/Consts.sol";
import { Loan, Types } from "../lib/Types.sol";

contract Loans is GlobalStore, Transfer, Debug, Consts {
    using SafeMath for uint256;
    using Loan for Types.Loan;

    event NewLoan(uint256 loanID);

    // struct Loan {
    //     uint256 id;
    //     bytes32 lenderOrderId;
    //     address lender;
    //     address borrower;
    //     address relayer;
    //     address asset;
    //     uint256 amount;
    //     uint16 interestRate;
    //     uint40 startAt;
    //     uint40 duration;
    //     uint16 relayerFeeRate;
    //     uint24 gasPrice;
    // }

    function calculateLoanInterest(Types.Loan memory loan, uint256 amount) public view returns (uint256 totalInterest, uint256 relayerFee) {
        uint256 timeDelta = getBlockTimestamp() - loan.startAt;
        totalInterest = amount.mul(loan.interestRate).mul(timeDelta).div(INTEREST_RATE_BASE.mul(SECONDS_OF_YEAR));
        relayerFee = totalInterest.mul(loan.relayerFeeRate).div(RELAYER_FEE_RATE_BASE);
        return (totalInterest, relayerFee);
    }

    function getLoansByIDs(uint256[] memory ids) internal view returns (Types.Loan[] memory loans) {
        loans = new Types.Loan[](ids.length);

        for( uint256 i = 0; i < ids.length; i++ ) {
            loans[i] = state.allLoans[ids[i]];
        }
    }

    function getUserLoans(address user) public view returns (Types.Loan[] memory loans) {
        uint256 defaultAccountID = state.userDefaultCollateralAccounts[user];

        if(defaultAccountID == 0) {
            return loans;
        } else {
            return getLoansByIDs(state.allCollateralAccounts[defaultAccountID].loanIDs);
        }

    }

    // function getBorrowerOverdueLoans(address user) public view returns (Types.Loan[] memory loans) {
    //     uint256[] memory ids = getUserLoans(user);
    //     uint256 j = 0;

    //     loans = new Types.Loan[](ids.length);

    //     for( uint256 i = 0; i < ids.length; i++ ) {
    //         Types.Loan memory loan = allLoans[ids[i]];
    //         if (isOverdueLoan(loan)) {
    //             loans[j++] = loan;
    //         }
    //     }
    // }

    function createLoan(Types.Loan memory loan) internal returns(uint256) {
        // TODO a max loans count, otherwize it may be impossible to liquidate his all loans in a single block
        uint256 id = state.loansCount++;
        state.allLoans[id] = loan;

        emit NewLoan(id); // TODO: move to events

        return id;
    }

    // payer give lender all money and interest
    function repayLoan(Types.Loan memory loan, address payer, uint256 amount) internal {
        (uint256 interest, uint256 relayerFee) = calculateLoanInterest(loan, amount);

        // borrowed amount and pay interest
        transferFrom(loan.asset, payer, loan.lender, amount.add(interest).sub(relayerFee));

        // TODO getLoanGasPrice(loan).mul(SIMULIZED_GAS_COST)
        uint256 gasCostInAsset = 0;
        uint256 fee = relayerFee.add(gasCostInAsset);

        // pay the fee
        transferFrom(loan.asset, payer, loan.relayer, fee);
        reduceLoan(loan, amount);
    }

    function reduceLoan(Types.Loan memory loan, uint256 amount) internal {
        loan.amount = loan.amount.sub(amount);
        allLoans[loan.id].amount = loan.amount;

        // partial close loan
        if (loan.amount > 0){
            return;
        }

        unlinkLoanAndUser(loan.id, loan.borrower);

        // TODO deltel loan?
    }
}