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

import "../lib/SafeMath.sol";

import { Loan, Types } from "../lib/Types.sol";
import "../lib/Events.sol";

contract Loans is GlobalStore, Transfer {
    using SafeMath for uint256;
    using Loan for Types.Loan;

    function getUserLoans(address user) public view returns (Types.Loan[] memory loans) {
        uint256 defaultAccountID = state.userDefaultCollateralAccounts[user];

        if(defaultAccountID == 0) {
            return loans;
        } else {
            return getLoansByIDs(state.allCollateralAccounts[defaultAccountID].loanIDs);
        }

    }

    function createLoan(Types.Loan memory loan) internal returns(uint256) {
        // TODO a max loans count, otherwize it may be impossible to liquidate his all loans in a single block
        uint256 id = state.loansCount++;
        state.allLoans[id] = loan;
        Events.logLoanCreate(id);
        return id;
    }
}