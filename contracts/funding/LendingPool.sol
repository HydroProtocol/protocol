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

/**
 *
 * Inside this library, the concept of normalizedAmount and poolIndex are used to simplify computations.
 * Index is a number that starts at 1 and increases as interest accumilates.
 * An index of 2 means 100% interest rate has bee accumiliated.
 * 
 * For an amount x, normalizedAmount = x/index. This means if you put in x/index in the beginning, it would be worth exactly x now.
 * The benefit of lining it this way is that its easier to aggregate and less book-keeping is needed.
 *
 * There are four primary operations for the lending pool:
 * supply, unsupply, borrow, repay. The order of operation is consistent for all of them:
 * 1. update index first, then compute the normalizedAmount
 * 2. transfer asset
 * 3. change normalizedAmount for supply and borrow
 * 4. update interest rate based on new state
 */


library LendingPool {
    using SafeMath for uint256;

    // create new pool
    function initializeAssetLendingPool(
        Store.State storage state,
        address asset
    )
        internal
    {
        // indexes starts at 1 for easy computation
        state.pool.borrowIndex[asset] = Decimal.one();
        state.pool.supplyIndex[asset] = Decimal.one();

        // record starting time for the pool
        state.pool.indexStartTime[asset] = block.timestamp;
    }

    /**
     * Supply asset into the pool. Supplied asset in the pool gains interest.
     */
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

        // update value of index at this moment in time
        updateIndex(state, asset);

        // compute the normalized value of 'amount'
        // round floor
        uint256 logicAmount = Decimal.divFloor(amount, state.pool.supplyIndex[asset]);

        // transfer asset from user's balance account
        balances[asset] = balances[asset].sub(amount);
        state.cash[asset] = state.cash[asset].sub(amount);

        // mint normalizedAmount of pool token for user
        state.assets[asset].lendingPoolToken.mint(user, logicAmount);

        // update interest rate based on latest state
        updateInterestRate(state, asset);

        Events.logSupply(user, asset, amount);
    }

    /**
     * Withdraw asset from the pool, up to initial asset supplied plus interest
     */
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

        // update value of index at this moment in time
        updateIndex(state, asset);

        // compute the normalized value of 'amount'
        // round ceiling
        uint256 logicAmount = Decimal.divCeil(amount, state.pool.supplyIndex[asset]);

        uint256 withdrawAmount = amount;

        // check and cap the amount so user can't overdraw
        if (getLogicSupplyOf(state, asset, user) <= logicAmount) {
            logicAmount = getLogicSupplyOf(state, asset, user);
            withdrawAmount = Decimal.mulFloor(logicAmount, state.pool.supplyIndex[asset]);
        }

        // transfer asset to user's balance account
        balances[asset] = balances[asset].add(withdrawAmount);
        state.cash[asset] = state.cash[asset].add(withdrawAmount);
        Requires.requireCashLessThanOrEqualContractBalance(state, asset);

        // subtract normalizedAmount from the pool
        state.assets[asset].lendingPoolToken.burn(user, logicAmount);

        // update interest rate based on latest state
        updateInterestRate(state, asset);

        Events.logUnsupply(user, asset, withdrawAmount);

        return withdrawAmount;
    }

    /**
     * Borrow money from the lending pool.
     */
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

        // update value of index at this moment in time
        updateIndex(state, asset);

        // compute the normalized value of 'amount'
        uint256 logicAmount = Decimal.divCeil(amount, state.pool.borrowIndex[asset]);

        // transfer assets to user's balance account
        balances[asset] = balances[asset].add(amount);
        state.cash[asset] = state.cash[asset].add(amount);
        Requires.requireCashLessThanOrEqualContractBalance(state, asset);

        // update normalized amount borrowed by user
        state.pool.logicBorrow[user][marketID][asset] = state.pool.logicBorrow[user][marketID][asset].add(logicAmount);

        // update normalized amount borrowed from the pool
        state.pool.logicTotalBorrow[asset] = state.pool.logicTotalBorrow[asset].add(logicAmount);

        // update interest rate based on latest state
        updateInterestRate(state, asset);

        require(
            !CollateralAccounts.getDetails(state, user, marketID).liquidatable,
            "MARKET_ACCOUNT_IS_LIQUIDABLE_AFTER_BORROW"
        );

        Events.logBorrow(user, marketID, asset, amount);
    }

    /**
     * repay money borrowed money from the pool.
     */
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

        // update value of index at this moment in time
        updateIndex(state, asset);

        // get normalized value of amount to be repaid, which in effect take into account interest
        // (ex: if you borrowed 10, with index at 1.1, amount repaid needs to be 11 to make 11/1.1 = 10)
        uint256 logicAmount = Decimal.divFloor(amount, state.pool.borrowIndex[asset]);

        uint256 repayAmount = amount;

        // make sure user cannot repay more than amount owed
        if (state.pool.logicBorrow[user][marketID][asset] <= logicAmount){
            logicAmount = state.pool.logicBorrow[user][marketID][asset];
            // repayAmount <= amount
            // because ⌈⌊a/b⌋*b⌉ <= a
            repayAmount = Decimal.mulCeil(logicAmount, state.pool.borrowIndex[asset]);
        }

        // transfer assets from user's balance account
        balances[asset] = balances[asset].sub(repayAmount);
        state.cash[asset] = state.cash[asset].sub(repayAmount);

        // update amount(normalized) borrowed by user
        state.pool.logicBorrow[user][marketID][asset] = state.pool.logicBorrow[user][marketID][asset].sub(logicAmount);

        // update total amount(normalized) borrowed from pool
        state.pool.logicTotalBorrow[asset] = state.pool.logicTotalBorrow[asset].sub(logicAmount);

        // update interest rate
        updateInterestRate(state, asset);

        Events.logRepay(user, marketID, asset, repayAmount);

        return repayAmount;
    }

    /**
     * This method is called if a loan could not be paid back by the borrower, auction, or insurance,
     * in which case the generalized loss is recognized across all lenders.
     */
    function recognizeLoss(
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

    /**
     * Claim an amount from the insurance pool, in return for all the collateral.
     * Only called if an auction expired without being filled.
     */
    function claimInsurance(
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
            recognizeLoss(
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

    /**
     * update the index value
     */
    function updateIndex(
        Store.State storage state,
        address asset
    )
        internal
    {
        (uint256 currentSupplyIndex, uint256 currentBorrowIndex) = getCurrentIndex(state, asset);

        // get the total equity value
        uint256 logicBorrow = state.pool.logicTotalBorrow[asset];
        uint256 logicSupply = getTotalLogicSupply(state, asset);

        // interest = equity value * (current index value - starting index value)
        uint256 borrowInterest = Decimal.mulCeil(logicBorrow, currentBorrowIndex).
        sub(Decimal.mulCeil(logicBorrow, state.pool.borrowIndex[asset]));

        uint256 supplyInterest = Decimal.mulFloor(logicSupply, currentSupplyIndex).
        sub(Decimal.mulFloor(logicSupply, state.pool.supplyIndex[asset]));

        // the interest rate spread goes into the insurance pool
        state.pool.insuranceBalances[asset] = state.pool.insuranceBalances[asset].add(borrowInterest.sub(supplyInterest));

        // update the indexes
        state.pool.supplyIndex[asset] = currentSupplyIndex;
        state.pool.borrowIndex[asset] = currentBorrowIndex;
        state.pool.indexStartTime[asset] = block.timestamp;
    }

    function getAmountSupplied(
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

    function getAmountBorrowed(
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

        // the actual amount borrowed = normalizedAmount * poolIndex
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

    /**
     * Compute the current value of poolIndex based on the time elapsed and the interest rate
     */
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