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
    uint256 public constant SECONDS_OF_YEAR = 31536000;

    mapping(bytes32 => Loan) public loansById;
    mapping(address => Loan[]) public loansByBorrower;

    struct Loan {
        bytes32 lenderOrderId;
        address lender;
        address borrower;
        address asset;
        uint256 amount;
        uint256 interestRate;
        uint256 startTime;
        uint256 duration;
    }

    function hashLoan(Loan memory loan) internal pure returns (bytes32 result) {
        assembly {
            result := keccak256(loan, 256)
        }
        return result;
    }

    function isLoanExpired(bytes32 loanId) public view returns (bool expired) {
        Loan memory loan = loansById[loanId];
        return loan.startTime+loan.duration>block.timestamp;
    }

    function calculateLoanInterest(bytes32 loanId) public view returns (uint256 interest) {
        Loan memory loan = loansById[loanId];
        uint256 timeDelta = block.timestamp - loan.startTime;
        interest = loan.amount * loan.interestRate * timeDelta / INTEREST_RATE_BASE / SECONDS_OF_YEAR;
        return interest;
    }

}