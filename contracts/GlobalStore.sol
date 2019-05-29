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

pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "./lib/Store.sol";
import { Types } from "./lib/Types.sol";
import "./lib/Events.sol";
/**
 * Global state store
 */
contract GlobalStore {
    Store.State state;

    // Setter Methods

    /**
     * Create a auction for a loan and save it in global state
     *
     * @param loanID                 ID of liquidated loan
     * @param loanAmount             Debt Amount of liquidated loan, unmodifiable
     * @param collateralAssetAmounts Assets Amounts for auction
     */
    function createAuction(uint32 loanID, uint256 loanAmount, uint256[] memory collateralAssetAmounts)
        internal
    {
        uint32 id = state.auctionsCount++;

        Types.Auction memory auction = Types.Auction({
            id: id,
            startBlockNumber: uint32(block.number),
            loanID: loanID,
            totalLoanAmount: loanAmount
        });

        state.allAuctions[id] = auction;

        for (uint256 i = 0; i < collateralAssetAmounts.length; i++ ) {
            state.allAuctions[id].assetAmounts[i] = collateralAssetAmounts[i];
        }

        Events.logAuctionCreate(id);
    }

    function removeLoanIDFromCollateralAccount(uint256 loanID, uint256 accountID) internal {
        Types.CollateralAccount storage account = state.allCollateralAccounts[accountID];

        for (uint32 i = 0; i < account.loanIDs.length; i++){
            if (account.loanIDs[i] == loanID) {
                account.loanIDs[i] = account.loanIDs[account.loanIDs.length-1];
                delete account.loanIDs[account.loanIDs.length - 1];
                account.loanIDs.length--;
                break;
            }
        }
    }

    // Getter Methods

    function getLoansByIDs(uint32[] memory loanIDs) internal view returns (Types.Loan[] memory loans) {
        loans = new Types.Loan[](loanIDs.length);

        for( uint256 i = 0; i < loanIDs.length; i++ ) {
            loans[i] = state.allLoans[loanIDs[i]];
        }
    }

    // for debug only

    uint256 internal updatedTimestamp = 0;

    function getBlockTimestamp() internal view returns (uint40) {
        if (updatedTimestamp > 0) {
            return uint40(updatedTimestamp);
        } else {
            return uint40(block.timestamp);
        }
    }

    function setBlockTimestamp(uint256 newTimestamp) public {
        updatedTimestamp = newTimestamp;
    }
}