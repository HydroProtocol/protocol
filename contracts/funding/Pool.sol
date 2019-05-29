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
import "../lib/Types.sol";
import "../lib/Consts.sol";
import "../GlobalStore.sol";

contract Pool is Consts, GlobalStore {
    using SafeMath for uint256;

    uint256 poolAnnualInterest;
    uint40 poolInterestStartTime;

    // total suppy and borrow
    mapping (uint16 => uint256) public totalSupply;
    mapping (uint16 => uint256) public totalBorrow;

    // assetID => total shares
    mapping (uint16 => uint256) totalSupplyShares;

    // assetID => user => shares
    mapping (uint16 => mapping (address => uint256)) supplyShares;

    // supply asset
    function supplyPool(uint16 assetID, uint256 amount) public {

        require(state.balances[assetID][msg.sender] >= amount, "USER_BALANCE_NOT_ENOUGH");

        // first supply
        if (totalSupply[assetID] == 0){
            state.balances[assetID][msg.sender] -= amount;
            totalSupply[assetID] = amount;
            supplyShares[assetID][msg.sender] = amount;
            totalSupplyShares[assetID] = amount;
            return ;
        }

        // accrue interest
        _accrueInterest(assetID);

        // new supply shares
        uint256 shares = amount.mul(totalSupplyShares[assetID]).div(totalSupply[assetID]);
        state.balances[assetID][msg.sender] -= amount;
        totalSupply[assetID] = totalSupply[assetID].add(amount);
        supplyShares[assetID][msg.sender] = supplyShares[assetID][msg.sender].add(shares);
        totalSupplyShares[assetID] = totalSupplyShares[assetID].add(shares);

    }

    // withdraw asset
    // to avoid precision problem, input share amount instead of token amount
    function withdrawPool(uint16 assetID, uint256 sharesAmount) public {

        uint256 assetAmount = sharesAmount.mul(totalSupply[assetID]).div(totalSupplyShares[assetID]);
        require(sharesAmount <= supplyShares[assetID][msg.sender], "USER_BALANCE_NOT_ENOUGH");
        require(assetAmount.add(totalBorrow[assetID]) <= totalSupply[assetID], "POOL_BALANCE_NOT_ENOUGH");

        supplyShares[assetID][msg.sender] -= sharesAmount;
        totalSupplyShares[assetID] -= sharesAmount;
        totalSupply[assetID] -= assetAmount;
        state.balances[assetID][msg.sender] += assetAmount;

    }

    // borrow and repay
    function borrowPool(
        uint32 collateralAccountId,
        uint16 assetID,
        uint256 amount,
        uint16 maxInterestRate,
        uint40 minExpiredAt
    ) internal returns (uint32[] memory loanIds){

        // check amount & interest
        uint16 interestRate = getInterestRate(assetID, amount);
        require(interestRate <= maxInterestRate, "INTEREST_RATE_EXCEED_LIMITATION");
        _accrueInterest(assetID);

        // build loan
        Types.Loan memory loan = Types.Loan(
            state.loansCount++,
            assetID,
            collateralAccountId,
            uint40(block.timestamp),
            minExpiredAt,
            interestRate,
            Types.LoanSource.Pool,
            amount
        );

        // record global loan
        state.allLoans[loan.id] = loan;

        // record collateral account loan
        Types.CollateralAccount storage account = state.allCollateralAccounts[collateralAccountId];
        account.loanIDs.push(loan.id);

        // set borrow amount
        totalBorrow[assetID] += amount;
        poolAnnualInterest += amount.mul(interestRate).div(INTEREST_RATE_BASE);

        loanIds[0] = loan.id;
        return loanIds;

    }

    function repayPool(uint32 loanId, uint256 amount) internal {

        Types.Loan storage loan = state.allLoans[loanId];
        require(loan.source==Types.LoanSource.Pool, "LOAN_NOT_CREATED_BY_POOL");

        require(amount <= loan.amount, "REPAY_AMOUNT_TOO_MUCH");

        // minus first and add second
        poolAnnualInterest -= uint256(loan.interestRate).mul(loan.amount).div(INTEREST_RATE_BASE);
        loan.amount -= amount;
        poolAnnualInterest += uint256(loan.interestRate).mul(loan.amount).div(INTEREST_RATE_BASE);

        totalBorrow[loan.assetID] -= amount;

    }

    // get interestRate
    function getInterestRate(uint16 assetID, uint256 amount) public view returns(uint16 interestRate){
        // 使用计提利息后的supply
        uint256 interest = _getUnpaidInterest(assetID);

        uint256 supply = totalSupply[assetID].add(interest);
        uint256 borrow = totalBorrow[assetID].add(amount);

        require(supply >= borrow, "BORROW_EXCEED_LIMITATION");

        uint256 borrowRatio = borrow.mul(INTEREST_RATE_BASE).div(supply);

        // 0.2r + 0.5r^2
        uint256 rate1 = borrowRatio.mul(INTEREST_RATE_BASE).mul(2);
        uint256 rate2 = borrowRatio.mul(borrowRatio).mul(5);

        return uint16(rate1.add(rate2).div(INTEREST_RATE_BASE.mul(10)));
    }

    // accrue interest to totalSupply
    function _accrueInterest(uint16 assetID) internal {

        // interest since last update
        uint256 interest = _getUnpaidInterest(assetID);

        // accrue interest to supply
        totalSupply[assetID] = totalSupply[assetID].add(interest);

        // update interest time
        poolInterestStartTime = uint40(block.timestamp);
    }

    function _getUnpaidInterest(uint16 assetID) internal view returns(uint256) {
        uint256 interest = block.timestamp
            .sub(poolInterestStartTime)
            .mul(poolAnnualInterest)
            .div(SECONDS_OF_YEAR);
        return interest;
    }

}