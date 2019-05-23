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

import "../lib/SafeMath.sol";

import "./Consts.sol";
import "./ProxyCaller.sol";

import "../helper/Debug.sol";

contract Loans is Debug, Consts, ProxyCaller {
    using SafeMath for uint256;

    uint256 public loansCount;
    mapping(uint256 => Loan) public allLoans;
    mapping(address => uint256[]) public loansByBorrower;

    mapping(uint256 => bool) public liquidLoans;

    event NewLoan(uint256 loanID);

    struct Loan {
        uint256 id;
        bytes32 lenderOrderId;
        address lender;
        address borrower;
        address relayer;
        address asset;
        uint256 amount;
        uint16 interestRate;
        uint40 startAt;
        uint40 duration;
        uint16 relayerFeeRate;
        uint24 gasPrice;
    }

    function getLoanInterestRate(bytes32 data) internal pure returns (uint256) {
        return uint256(uint16(bytes2(data)));
    }

    function getLoanStartAt(bytes32 data) internal pure returns (uint256) {
        return uint256(uint40(bytes5(data << 8*2)));
    }

    function getLoanDuration(bytes32 data) internal pure returns (uint256) {
        return uint256(uint40(bytes5(data << 8*7)));
    }

    function getLoanRelayerFeeRate(bytes32 data) internal pure returns (uint256) {
        return uint256(uint16(bytes2(data << 8*12)));
    }

    function getLoanGasPrice(bytes32 data) internal pure returns (uint256) {
        return uint256(uint24(bytes3(data << 8*14)));
    }

    function isOverdueLoan(Loan memory loan) public view returns (bool expired) {
        return loan.startAt + loan.duration < getBlockTimestamp();
    }

    function calculateLoanInterest(Loan memory loan, uint256 amount) public view returns (uint256 totalInterest, uint256 relayerFee) {
        uint256 timeDelta = getBlockTimestamp() - loan.startAt;
        totalInterest = amount.mul(loan.interestRate).mul(timeDelta).div(INTEREST_RATE_BASE.mul(SECONDS_OF_YEAR));
        relayerFee = totalInterest.mul(loan.relayerFeeRate).div(RELAYER_FEE_RATE_BASE);
        return (totalInterest, relayerFee);
    }

    function getLoansByIDs(uint256[] memory ids) internal view returns (Loan[] memory loans) {
        loans = new Loan[](ids.length);

        for( uint256 i = 0; i < ids.length; i++ ) {
            loans[i] = allLoans[ids[i]];
        }
    }

    function getBorrowerLoans(address user) public view returns (Loan[] memory loans) {
        uint256[] memory ids = loansByBorrower[user];
        // return getLoansByIDs(loansByBorrower[user]);

        loans = new Loan[](ids.length);
        uint256 j;
        for( uint256 i = 0; i < ids.length; i++ ) {
            Loan memory loan = allLoans[ids[i]];

            if(!liquidLoans[loan.id]) {
                loans[j++] = loan;
            }
        }

        return loans;
    }

    function getBorrowerOverdueLoans(address user) public view returns (Loan[] memory loans) {
        uint256[] memory ids = loansByBorrower[user];
        uint256 j = 0;

        loans = new Loan[](ids.length);

        for( uint256 i = 0; i < ids.length; i++ ) {
            Loan memory loan = allLoans[ids[i]];
            if (isOverdueLoan(loan)) {
                loans[j++] = loan;
            }
        }
    }

    function createLoan(Loan memory loan) internal {
        // TODO a max loans count, otherwize it may be impossible to liquidate his all loans in a single block

        uint256 id = loansCount++;
        allLoans[id] = loan;
        loansByBorrower[loan.borrower].push(id);

        emit NewLoan(id);
    }

    // payer give lender all money and interest
    function repayLoan(Loan memory loan, address payer, uint256 amount) internal {
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

    function reduceLoan(Loan memory loan, uint256 amount) internal {
        loan.amount = loan.amount.sub(amount);
        allLoans[loan.id].amount = loan.amount;

        // partial close loan
        if (loan.amount > 0){
            return;
        }

        uint256[] storage borrowerLoanIDs = loansByBorrower[loan.borrower];

        for (uint256 i = 0; i < borrowerLoanIDs.length; i++){
            if (borrowerLoanIDs[i] == loan.id) {
                borrowerLoanIDs[i] = borrowerLoanIDs[borrowerLoanIDs.length-1];
                delete borrowerLoanIDs[borrowerLoanIDs.length - 1];
                borrowerLoanIDs.length--;
                break;
            }
        }

        delete liquidLoans[loan.id];
        // TODO deltel loan?
    }
}