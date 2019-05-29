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
import "../lib/Store.sol";

contract Pool is Consts, Store {
    using SafeMath for uint256;

    uint256 poolAnnualInterest;
    uint256 poolInterestStartTime;

    // total suppy and borrow
    mapping (uint16 => uint256) public totalSupply;
    mapping (uint16 => uint256) public totalBorrow;

    // assetId => total shares
    mapping (uint16 => uint256) totalSupplyShares;

    // assetId => user => shares
    mapping (uint16 => mapping (address => uint256)) supplyShares;

    // supply asset
    function supplyToPool(uint16 assetId, uint256 amount) public {

        require(state.balances[assetId][msg.sender] >= amount, "USER_BALANCE_NOT_ENOUGH");

        // first supply
        if (totalSupply[assetId] == 0){
            state.balances[assetId][msg.sender] -= amount;
            totalSupply[assetId] = amount;
            supplyShares[assetId][msg.sender] = amount;
            totalSupplyShares[assetId] = amount;
            return ;
        }

        // accrue interest
        _accrueInterest(assetId);

        // new supply shares
        uint256 shares = amount.mul(totalSupplyShares[assetId]).div(totalSupply[assetId]);
        state.balances[assetId][msg.sender] -= amount;
        totalSupply[assetId] = totalSupply[assetId].add(amount);
        supplyShares[assetId][msg.sender] = supplyShares[assetId][msg.sender].add(shares);
        totalSupplyShares[assetId] = totalSupplyShares[assetId].add(shares);

    }

    // withdraw asset
    // to avoid precision problem, input share amount instead of token amount
    function withdraw(address asset, uint256 sharesAmount) public {

        uint256 assetAmount = sharesAmount.mul(totalSupply[asset]).div(totalSupplyShares[asset]);
        require(sharesAmount <= supplyShares[asset][msg.sender], "USER_BALANCE_NOT_ENOUGH");
        require(assetAmount <= totalSupply[asset], "POOL_BALANCE_NOT_ENOUGH");

        supplyShares[asset][msg.sender] -= sharesAmount;
        totalSupplyShares[asset] -= sharesAmount;
        totalSupply[asset] -= assetAmount;
        state.balances[asset][msg.sender] += assetAmount;

    }

    // borrow and repay
    function borrowInternal(
        uint256 collateralAccount,
        uint16 assetId,
        uint256 amount,
        uint16 maxInterestRate,
        uint16 minExpiredAt
    ) internal returns (bytes32[] memory loanIds){

        // check amount & interest
        uint16 interestRate = getInterest(assetId, amount);
        require(interestRate <= maxInterestRate, "INTEREST_RATE_EXCEED_LIMITATION");

        // build loan
        Types.LoanLender memory lender = Types.LoanLender(address(this), interestRate, amount, "");
        Types.LoanLender[] memory lenders = new Types.LoanLender[](1);
        lenders[0] = lender;

        Types.Loan memory loan = Types.Loan(
            state.loansCount++,
            0,
            lenders,
            collateralAccount,
            amount,
            assetId,
            block.timestamp,
            minExpiredAt,
            interestRate
        );

        state.allLoans[loan.id] = loan;
        state.loansByAccount[collateralAccount].push(loan.id);

        loanIds[0] = loan.id;

        // set borrow amount
        _accrueInterest(assetId);
        totalBorrow += amount;
        poolAnnualInterest += amount.mul(interestRate).div(LibConsts.getInterestRateBase());

        return loanIds;

    }

    function repayInternal(uint32 loanId, uint256 amount) internal {

        Types.Loan storage loan = state.allLoans[loanId];
        require(loan._type==0, "LOAN_NOT_CREATED_BY_POOL");

        require(amount <= loan.amount, "REPAY_AMOUNT_TOO_MUCH");

        uint256 interestRate = loan.averageInterestRate;

        // minus first and add second
        poolAnnualInterest -= loan.averageInterestRate.mul(loan.amount).div(LibConsts.getInterestRateBase());
        loan.amount -= amount;
        poolAnnualInterest += loan.averageInterestRate.mul(loan.amount).div(LibConsts.getInterestRateBase());

        totalBorrow[loan.asset] -= amount;

    }

    // get interest
    function getInterest(uint16 assetId, uint256 amount) public view returns(uint16 interestRate){
        // 使用计提利息后的supply
        uint256 interest = block.timestamp
            .sub(poolInterestStartTime)
            .mul(poolAnnualInterest)
            .div(LibConsts.getSecondsOfYear());

        uint256 supply = totalSupply[assetId].add(interest);
        uint256 borrow = totalBorrow[assetId].add(amount);

        require(supply >= borrow, "BORROW_EXCEED_LIMITATION");

        uint256 interestRateBase = LibConsts.getInterestRateBase();
        uint256 borrowRatio = borrow.mul(interestRateBase).div(supply);

        // 0.2r + 0.5r^2
        uint256 rate1 = borrowRatio.mul(interestRateBase).mul(2);
        uint256 rate2 = borrowRatio.mul(borrowRatio).mul(5);
        return rate1.add(rate2).div(interestRateBase.mul(10));
    }

    // accrue interest to totalSupply
    function _accrueInterest(uint16 assetId) internal {

        // interest since last update
        uint256 interest = block.timestamp
            .sub(poolInterestStartTime)
            .mul(poolAnnualInterest)
            .div(SECONDS_OF_YEAR);

        // accrue interest to supply
        totalSupply[assetId] = totalSupply[assetId].add(interest);

        // update interest time
        poolInterestStartTime = block.timestamp;
    }

}