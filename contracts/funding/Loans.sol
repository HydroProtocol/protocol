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

import "../lib/Store.sol";
import "../lib/SafeMath.sol";
import { Types } from "../lib/Types.sol";
import "../lib/Events.sol";

library Loans {
    using SafeMath for uint256;
    // using Loan for Types.Loan;

    function getByIDs(Store.State storage state, uint32[] memory loanIDs) internal view returns (Types.Loan[] memory loans) {
        loans = new Types.Loan[](loanIDs.length);

        for( uint256 i = 0; i < loanIDs.length; i++ ) {
            loans[i] = state.allLoans[loanIDs[i]];
        }
    }

    function getUserLoans(Store.State storage state, address user) internal view returns (Types.Loan[] memory loans) {
        uint256 defaultAccountID = state.userDefaultCollateralAccounts[user];

        if(defaultAccountID == 0) {
            return loans;
        } else {
            return getByIDs(state, state.allCollateralAccounts[defaultAccountID].loanIDs);
        }
    }

    function create(Store.State storage state, Types.Loan memory loan) internal returns(uint256) {
        // TODO a max loans count, otherwize it may be impossible to liquidate his all loans in a single block
        uint32 id = state.loansCount++;
        loan.id = id;
        state.allLoans[id] = loan;
        Events.logLoanCreate(id);
        return id;
    }
}