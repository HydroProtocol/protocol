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
import "../lib/Decimal.sol";
import "../lib/Getters.sol";

library Pool {
    using SafeMath for uint256;

    // create new pool
    function createPool(
        Store.State storage state,
        uint16 assetID
    ) internal {
        state.pool.borrowIndex[assetID] = Decimal.one();
        state.pool.supplyIndex[assetID] = Decimal.one();
        state.pool.indexStartTime[assetID] = block.timestamp;
    }

    // four asset operation: supply, withdraw, borrow, repay
    // 1. update index first to get the right logic amount
    // 2. transfer asset
    // 3. change logic supply and logic borrow
    // 4. update interest rate

    function supply(
        Store.State storage state,
        uint16 assetID,
        uint256 amount
    ) internal {

        require(state.balances[msg.sender][assetID] >= amount, "USER_BALANCE_NOT_ENOUGH");

        // update index
        _updateIndex(state, assetID);

        // get logic amount
        // round floor
        uint256 logicAmount = Decimal.divFloor(amount, state.pool.supplyIndex[assetID]);

        // transfer asset
        state.balances[msg.sender][assetID] = state.balances[msg.sender][assetID].sub(amount);

        // update logic amount
        state.pool.locigSupply[assetID][msg.sender] = state.pool.locigSupply[assetID][msg.sender].add(logicAmount);
        state.pool.logicTotalSupply[assetID] = state.pool.logicTotalSupply[assetID].add(logicAmount);

        // update interest rate
        _updateInterestRate(state, assetID);
    }

    function withdraw(
        Store.State storage state,
        uint16 assetID,
        uint256 amount
    ) internal {

        // update index
        _updateIndex(state, assetID);

        // get logic amount
        // round ceil
        uint256 logicAmount = Decimal.divCeil(amount, state.pool.supplyIndex[assetID]);
        uint256 withdrawAmount = amount;
        if (state.pool.logicSupply[assetID][msg.sender] < logicAmount) {
            logicAmount = state.pool.logicSupply[assetID][msg.sender];
            withdrawAmount = logicAmount.mul(state.pool.supplyIndex[assetID]);
        }

        // transfer asset
        state.balances[msg.sender][assetID] = state.balances[msg.sender][assetID].add(withdrawAmount);

        // update logic amount
        state.pool.logicSupply[assetID][msg.sender] = state.pool.logicSupply[assetID][msg.sender].sub(logicAmount);
        state.pool.logicTotalSupply[assetID] = state.pool.logicTotalSupply[assetID].sub(logicAmount);

        // update interest rate
        _updateInterestRate(state, assetID);
    }

    function borrow(
        Store.State storage state,
        uint32 accountID,
        uint16 assetID,
        uint256 amount
    ) internal {

         // update index
        _updateIndex(state, assetID);

        // get logic amount
        uint256 logicAmount = Decimal.divCeil(amount, state.pool.borrowIndex[assetID]);

        // transfer assets
        state.accountBalances[accountID][assetID] = state.accountBalances[accountID][assetID].add(amount);

        // update logic amount
        state.pool.logicBorrow[assetID][accountID] = state.pool.logicBorrow[assetID][accountID].add(logicAmount);
        state.pool.logicTotalBorrow[assetID] = state.pool.logicTotalBorrow[assetID].add(logicAmount);

        require(isAccountSafe(accountID), "ACCOUNT_NOT_SAFE");

        // update interest rate
        _updateInterestRate(state, assetID);
    }

    function repay(
        Store.State storage state,
        uint16 assetID,
        uint32 accountID,
        uint256 amount
    ) internal {

        // update index
        _updateIndex(state, assetID);

        // get logic amount
        uint256 logicAmount = Decimal.divFloor(amount, state.pool.borrowIndex[assetID]);
        uint256 repayAmount = amount;
        // repay all logic amount greater than debt
        if (state.pool.logicBorrow[assetID][accountID] < logicAmount){
            logicAmount = state.pool.logicBorrow[assetID][accountID];
            repayAmount = Decimal.mul(logicAmount, state.pool.borrowIndex[assetID]);
        }

        // transfer assets
        state.accountBalances[accountID][assetID] = state.accountBalances[accountID][assetID].sub(repayAmount);

        // update logic amount
        state.pool.logicBorrow[assetID][accountID] = state.pool.logicBorrow[assetID][accountID].sub(logicAmount);
        state.pool.logicTotalBorrow[assetID] = state.pool.logicTotalBorrow[assetID].sub(logicAmount);

        // update interest rate
        _updateInterestRate(state, assetID);
    }


    function _updateInterestRate(
        Store.State storage state,
        uint16 assetID
    ) internal{
        (uint256 borrowInterestRate, uint256 supplyInterestRate) = _getInterestRate(state, assetID);
        state.pool.borrowAnnualInterestRate = borrowInterestRate;
        state.pool.supplyAnnualInterestRate = supplyInterestRate;
    }

    // get interestRate
    function _getInterestRate(
        Store.State storage state,
        uint16 assetID
    )
        internal
        view
        returns(uint256 borrowInterestRate, uint256 supplyInterestRate)
    {

        uint256 _supply = Getters._getPoolTotalSupply(state, assetID);
        uint256 _borrow = Getters._getPoolTotalBorrow(state, assetID);

        require(_supply >= _borrow, "BORROW_EXCEED_LIMITATION");

        if (supply == 0) {
            return (0, 0);
        }

        uint256 borrowRatio = _borrow.mul(Decimal.one()).div(_supply);

        // 0.2r + 0.5r^2
        uint256 rate1 = borrowRatio.mul(2).div(10);
        uint256 rate2 = Decimal.mul(borrowRatio, borrowRatio).mul(5).div(10);
        borrowInterestRate = rate1.add(rate2);
        supplyInterestRate = borrowInterestRate.mul(_borrow).div(_supply);

        return (borrowInterestRate, supplyInterestRate);
    }

    function _updateIndex(Store.State storage state, uint16 assetID) internal {
        (uint256 currentSupplyIndex, uint256 currentBorrowIndex) = Getters._getPoolCurrentIndex(state, assetID);
        state.pool.supplyIndex[assetID] = currentSupplyIndex;
        state.pool.borrowIndex[assetID] = currentBorrowIndex;
        state.pool.indexStartTime[assetID] = block.timestamp;
    }

}