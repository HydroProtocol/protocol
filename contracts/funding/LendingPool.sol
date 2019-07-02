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
import "../lib/Events.sol";
import "../lib/Requires.sol";
import "../lib/ExternalCaller.sol";
import "./CollateralAccounts.sol";

library LendingPool {
    using SafeMath for uint256;

    // create new pool
    function initializeAssetLendingPool(
        Store.State storage state,
        address asset
    )
        internal
    {
        state.pool.borrowIndex[asset] = Decimal.one();
        state.pool.supplyIndex[asset] = Decimal.one();
        state.pool.indexStartTime[asset] = block.timestamp;
    }

    // four asset operation: supply, withdraw, borrow, repay
    // 1. update index first to get the right logic amount
    // 2. transfer asset
    // 3. change logic supply and logic borrow
    // 4. update interest rate

    function supply(
        Store.State storage state,
        address asset,
        uint256 amount,
        address user
    )
        internal
    {
        Requires.requireAssetExist(state, asset);

        mapping(address => uint256) storage balances = state.balances[user];

        // update index
        updateIndex(state, asset);

        // get logic amount
        // round floor
        uint256 logicAmount = Decimal.divFloor(amount, state.pool.supplyIndex[asset]);

        // transfer asset
        balances[asset] = balances[asset].sub(amount);
        state.cash[asset] = state.cash[asset].sub(amount);

        // mint pool token
        state.assets[asset].lendingPoolToken.mint(user, logicAmount);

        // update interest rate
        updateInterestRate(state, asset);

        Events.logSupply(user, asset, amount);
    }

    function withdraw(
        Store.State storage state,
        address asset,
        uint256 amount,
        address user
    )
        internal
        returns (uint256)
    {
        Requires.requireAssetExist(state, asset);
        mapping(address => uint256) storage balances = state.balances[user];

        // update index
        updateIndex(state, asset);

        // get logic amount
        // round ceil
        uint256 logicAmount = Decimal.divCeil(amount, state.pool.supplyIndex[asset]);
        uint256 withdrawAmount = amount;

        if (getLogicSupplyOf(state, asset, user) <= logicAmount) {
            logicAmount = getLogicSupplyOf(state, asset, user);
            withdrawAmount = Decimal.mulFloor(logicAmount, state.pool.supplyIndex[asset]);
        }

        // transfer asset
        balances[asset] = balances[asset].add(withdrawAmount);
        state.cash[asset] = state.cash[asset].add(withdrawAmount);
        Requires.requireCashLessThanOrEqualContractBalance(state, asset);

        // update logic amount
        state.assets[asset].lendingPoolToken.burn(user, logicAmount);

        // update interest rate
        updateInterestRate(state, asset);

        Events.logUnsupply(user, asset, withdrawAmount);

        return withdrawAmount;
    }

    function borrow(
        Store.State storage state,
        address user,
        uint16 marketID,
        address asset,
        uint256 amount
    )
        internal
    {
        Requires.requireMarketIDAndAssetMatch(state, marketID, asset);

        mapping(address => uint256) storage balances = state.accounts[user][marketID].balances;

         // update index
        updateIndex(state, asset);

        // get logic amount
        uint256 logicAmount = Decimal.divCeil(amount, state.pool.borrowIndex[asset]);

        // transfer assets
        balances[asset] = balances[asset].add(amount);
        state.cash[asset] = state.cash[asset].add(amount);
        Requires.requireCashLessThanOrEqualContractBalance(state, asset);

        // update logic amount
        state.pool.logicBorrow[user][marketID][asset] = state.pool.logicBorrow[user][marketID][asset].add(logicAmount);
        state.pool.logicTotalBorrow[asset] = state.pool.logicTotalBorrow[asset].add(logicAmount);

        // update interest rate
        updateInterestRate(state, asset);

        Requires.requireCollateralAccountNotLiquidatable(state, user, marketID);

        Events.logBorrow(user, marketID, asset, amount);
    }

    // the user repay no more than amount
    function repay(
        Store.State storage state,
        address user,
        uint16 marketID,
        address asset,
        uint256 amount
    )
        internal
        returns (uint256)
    {
        Requires.requireMarketIDAndAssetMatch(state, marketID, asset);

        mapping(address => uint256) storage balances = state.accounts[user][marketID].balances;

        // update index
        updateIndex(state, asset);

        // get logic amount
        uint256 logicAmount = Decimal.divFloor(amount, state.pool.borrowIndex[asset]);
        uint256 repayAmount = amount;

        // repay all logic amount
        if (state.pool.logicBorrow[user][marketID][asset] <= logicAmount){
            logicAmount = state.pool.logicBorrow[user][marketID][asset];
            // repayAmount <= amount
            // because ⌈⌊a/b⌋*b⌉ <= a
            repayAmount = Decimal.mulCeil(logicAmount, state.pool.borrowIndex[asset]);
        }

        // transfer assets
        balances[asset] = balances[asset].sub(repayAmount);
        state.cash[asset] = state.cash[asset].sub(repayAmount);

        // update logic amount
        state.pool.logicBorrow[user][marketID][asset] = state.pool.logicBorrow[user][marketID][asset].sub(logicAmount);
        state.pool.logicTotalBorrow[asset] = state.pool.logicTotalBorrow[asset].sub(logicAmount);

        // update interest rate
        updateInterestRate(state, asset);

        Events.logRepay(user, marketID, asset, repayAmount);

        return repayAmount;
    }

    function lose(
        Store.State storage state,
        address asset,
        uint256 amount
    )
        internal
    {
        uint256 totalLogicSupply = getTotalLogicSupply(
            state,
            asset
        );

        uint256 actualSupply = getTotalSupply(
            state,
            asset
        ).sub(amount);

        state.pool.supplyIndex[asset] = Decimal.divFloor(
            actualSupply,
            totalLogicSupply
        );

        state.cash[asset] = state.cash[asset].add(amount);

        Events.logLoss(asset, amount);
    }

    function compensate(
        Store.State storage state,
        address debtAsset,
        uint256 debtAmount
    )
        internal
    {
        uint256 insuranceBalance = state.pool.insuranceBalances[debtAsset];

        uint256 compensationAmount = Math.min(debtAmount, insuranceBalance);

        // remove compensationAmount from insurance balances
        state.pool.insuranceBalances[debtAsset] = SafeMath.sub(
            state.pool.insuranceBalances[debtAsset],
            compensationAmount
        );

        // all suppliers pay debt if insurance not enough
        if (compensationAmount < debtAmount){
            lose(
                state,
                debtAsset,
                debtAmount.sub(compensationAmount)
            );
        }

        Events.logInsuranceCompensation(
            debtAsset,
            compensationAmount
        );

    }

    function updateInterestRate(
        Store.State storage state,
        address asset
    )
        internal
    {
        (uint256 borrowInterestRate, uint256 supplyInterestRate) = getInterestRates(state, asset, 0);
        state.pool.borrowAnnualInterestRate[asset] = borrowInterestRate;
        state.pool.supplyAnnualInterestRate[asset] = supplyInterestRate;
    }

    // get interestRate
    function getInterestRates(
        Store.State storage state,
        address asset,
        uint256 extraBorrowAmount
    )
        internal
        view
        returns (uint256 borrowInterestRate, uint256 supplyInterestRate)
    {
        Requires.requireAssetExist(state, asset);

        uint256 _supply = getTotalSupply(state, asset);
        uint256 _borrow = getTotalBorrow(state, asset).add(extraBorrowAmount);

        if (_supply == 0) {
            return (0, 0);
        }

        uint256 borrowRatio = _borrow.mul(Decimal.one()).div(_supply);
        // borrowInterestRate = state.assets[asset].interestModel.polynomialInterestModel(borrowRatio);
        borrowInterestRate = ExternalCaller.getBorrowInterestRate(
            address(state.assets[asset].interestModel),
            borrowRatio
        );
        uint256 borrowInterest = Decimal.mulCeil(_borrow, borrowInterestRate);
        uint256 supplyInterest = Decimal.mulFloor(borrowInterest, Decimal.one().sub(state.pool.insuranceRatio));
        supplyInterestRate = Decimal.divFloor(supplyInterest, _supply);

        return (
            borrowInterestRate, supplyInterestRate
        );
    }

    function updateIndex(
        Store.State storage state,
        address asset
    )
        internal
    {
        (uint256 currentSupplyIndex, uint256 currentBorrowIndex) = getCurrentIndex(state, asset);

        uint256 logicBorrow = state.pool.logicTotalBorrow[asset];
        uint256 logicSupply = getTotalLogicSupply(state, asset);
        uint256 borrowInterest = Decimal.mulCeil(logicBorrow, currentBorrowIndex).sub(Decimal.mulCeil(logicBorrow, state.pool.borrowIndex[asset]));
        uint256 supplyInterest = Decimal.mulFloor(logicSupply, currentSupplyIndex).sub(Decimal.mulFloor(logicSupply, state.pool.supplyIndex[asset]));

        state.pool.insuranceBalances[asset] = state.pool.insuranceBalances[asset].add(borrowInterest.sub(supplyInterest));

        state.pool.supplyIndex[asset] = currentSupplyIndex;
        state.pool.borrowIndex[asset] = currentBorrowIndex;
        state.pool.indexStartTime[asset] = block.timestamp;
    }

    function getSupplyOf(
        Store.State storage state,
        address asset,
        address user
    )
        internal
        view
        returns (uint256)
    {
        Requires.requireAssetExist(state, asset);

        (uint256 currentSupplyIndex, ) = getCurrentIndex(state, asset);
        return Decimal.mulFloor(getLogicSupplyOf(state, asset, user), currentSupplyIndex);
    }

    function getBorrowOf(
        Store.State storage state,
        address asset,
        address user,
        uint16 marketID
    )
        internal
        view
        returns (uint256)
    {
        Requires.requireMarketIDAndAssetMatch(state, marketID, asset);

        (, uint256 currentBorrowIndex) = getCurrentIndex(state, asset);
        return Decimal.mulCeil(state.pool.logicBorrow[user][marketID][asset], currentBorrowIndex);

    }

    function getTotalSupply(
        Store.State storage state,
        address asset
    )
        internal
        view
        returns (uint256)
    {
        Requires.requireAssetExist(state, asset);

        (uint256 currentSupplyIndex, ) = getCurrentIndex(state, asset);
        return Decimal.mulFloor(getTotalLogicSupply(state, asset), currentSupplyIndex);
    }

    function getTotalBorrow(
        Store.State storage state,
        address asset
    )
        internal
        view
        returns (uint256)
    {
        Requires.requireAssetExist(state, asset);

        (, uint256 currentBorrowIndex) = getCurrentIndex(state, asset);
        return Decimal.mulCeil(state.pool.logicTotalBorrow[asset], currentBorrowIndex);
    }

    function getCurrentIndex(
        Store.State storage state,
        address asset
    )
        internal
        view
        returns (uint256 currentSupplyIndex, uint256 currentBorrowIndex)
    {
        uint256 timeDelta = block.timestamp.sub(state.pool.indexStartTime[asset]);
        uint256 secondsOfYear = Consts.SECONDS_OF_YEAR();

        uint256 borrowInterestRate = state.pool.borrowAnnualInterestRate[asset]
            .mul(timeDelta).divCeil(secondsOfYear); // Ceil Ensure asset greater than liability

        uint256 supplyInterestRate = state.pool.supplyAnnualInterestRate[asset]
            .mul(timeDelta) / secondsOfYear;

        currentBorrowIndex = Decimal.mulCeil(state.pool.borrowIndex[asset], Decimal.onePlus(borrowInterestRate));
        currentSupplyIndex = Decimal.mulFloor(state.pool.supplyIndex[asset], Decimal.onePlus(supplyInterestRate));

        return (currentSupplyIndex, currentBorrowIndex);
    }

    function getLogicSupplyOf(
        Store.State storage state,
        address asset,
        address user
    )
        internal
        view
        returns (uint256)
    {
        return state.assets[asset].lendingPoolToken.balanceOf(user);
    }

    function getTotalLogicSupply(
        Store.State storage state,
        address asset
    )
        internal
        view
        returns (uint256)
    {
        return state.assets[asset].lendingPoolToken.totalSupply();
    }
}