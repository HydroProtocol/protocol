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

import "./Consts.sol";
import "../lib/SafeMath.sol";

contract Loans is Consts {
    using SafeMath for uint256;

    uint256 public loansCount;
    mapping(uint256 => Loan) public allLoans;
    mapping(address => uint256[]) public loansByBorrower;

    struct Loan {
        uint256 id;
        bytes32 lenderOrderId;
        address lender;
        address borrower;
        address relayer;
        address asset;
        uint256 amount;

        /**
         * Data contains the following values packed into 32 bytes
         * ╔════════════════════╤═══════════════════════════════════════════════════════════╗
         * ║                    │ length(bytes)   desc                                      ║
         * ╟────────────────────┼───────────────────────────────────────────────────────────╢
         * ║ interestRate       │ 2               interest rate (base 10,000)               ║
         * ║ startAt            │ 5               start timestamp                           ║
         * ║ duration           │ 5               loan duration seconds                     ║
         * ║ relayerFeeRate     │ 2               fee rate (base 100,00)                    ║
         * ║ gasPrice           │ 3               gasPrice in Gwei                          ║
         * ║                    │ rest            salt                                      ║
         * ╚════════════════════╧═══════════════════════════════════════════════════════════╝
         */
        bytes32 data;
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

    function isLoanLiquidable(uint256 loanId) public view returns (bool expired) {
        Loan memory loan = allLoans[loanId]; // TODO gas optimization
        return getLoanStartAt(loan.data) + getLoanDuration(loan.data) < block.timestamp && loan.amount > 0;
    }

    function calculateLoanInterest(uint256 loanId) public view returns (uint256 totalInterest, uint256 relayerFee) {
        Loan memory loan = allLoans[loanId];
        uint256 timeDelta = block.timestamp - getLoanStartAt(loan.data);
        totalInterest = loan.amount.mul(getLoanInterestRate(loan.data)).mul(timeDelta).div(INTEREST_RATE_BASE.mul(SECONDS_OF_YEAR));
        relayerFee = totalInterest.mul(getLoanRelayerFeeRate(loan.data)).div(RELAYER_FEE_RATE_BASE);
        return (totalInterest, relayerFee);
    }

    function createLoan(Loan memory loan) internal {
        uint256 id = loansCount++;
        allLoans[id] = loan;
        loansByBorrower[loan.borrower].push(id);

        // emit Event
    }

    function reduceLoan(uint256 loanId, uint256 amount) internal {
        Loan storage loan = allLoans[loanId];
        loan.amount -= amount;

        // partial close loan
        if (loan.amount > 0){
            return;
        }

        // only delete loan form loansByBorrower
        // no need to delete loan from loansById
        uint256[] storage borrowerLoanIDs = loansByBorrower[loan.borrower];

        for (uint i = 0; i < borrowerLoanIDs.length; i++){
            if (borrowerLoanIDs[i] == loanId){
                borrowerLoanIDs[i] = borrowerLoanIDs[borrowerLoanIDs.length-1];
                delete borrowerLoanIDs[borrowerLoanIDs.length - 1];
                borrowerLoanIDs.length--;
                break;
            }
        }
    }
}