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

pragma solidity ^0.5.8;
pragma experimental ABIEncoderV2;

contract Loans {

    uint256 public constant INTEREST_RATE_BASE = 10000;
    uint256 public constant RELAYER_FEE_RATE_BASE = 100;
    uint256 public constant SECONDS_OF_YEAR = 31536000;

    mapping(bytes32 => Loan) public loansById;
    mapping(address => bytes32[]) public loansByBorrower;

    struct Loan {
        bytes32 lenderOrderId;
        address lender;
        address borrower;
        address relayer;
        address asset;
        uint256 amount;
        uint256 interestRate;
        uint256 relayerFeeRate;
        uint256 startTime;
        uint256 duration;
    }

    function hashLoan(Loan memory loan) internal pure returns (bytes32 result) {
        assembly {
            // 32 * 10 = 320
            result := keccak256(loan, 320)
        }
        return result;
    }

    function isLoanExpired(bytes32 loanId) public view returns (bool expired) {
        return loansById[loanId].startTime+loansById[loanId].duration>block.timestamp && loansById[loanId].amount>0;
    }

    function calculateLoanInterest(bytes32 loanId, uint256 amount) public view returns (
        uint256 totalInterest,
        uint256 relayerFee
    ) {
        uint256 timeDelta = block.timestamp - loansById[loanId].startTime;
        totalInterest = amount * loansById[loanId].interestRate * timeDelta / INTEREST_RATE_BASE / SECONDS_OF_YEAR;
        relayerFee = totalInterest * loansById[loanId].relayerFeeRate/RELAYER_FEE_RATE_BASE;
        return (totalInterest, relayerFee);
    }

    function recordNewLoan(Loan memory loan) internal {
        bytes32 loanId = hashLoan(loan);
        loansById[loanId] = loan;
        loansByBorrower[loan.borrower].push(loanId);
    }

    function reduceLoan(bytes32 loanId, uint256 amount) internal {
        if (loansById[loanId].amount == amount){
            // only delete loan form loansByBorrower
            // no need to delete loan from loansById
            bytes32[] storage borrowerLoans = loansByBorrower[loansById[loanId].borrower];
            for (uint i = 0; i<borrowerLoans.length;i++){
                if (borrowerLoans[i]==loanId){
                    delete borrowerLoans[i];
                    borrowerLoans[i] = borrowerLoans[borrowerLoans.length-1];
                    break;
                }
            }
        } else {
            loansById[loanId].amount -= amount;
        }
    }

}