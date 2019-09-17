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
import "../lib/Transfer.sol";
import "../lib/Store.sol";
import "../lib/Decimal.sol";
import "../lib/Events.sol";
import "../lib/Requires.sol";
import "../lib/AssemblyCall.sol";

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
 * supply, unsupply, borrow, repay. The order of operation needs to be consistent:
 * 1. update index first, then compute the normalizedAmount
 * 2. transfer asset
 * 3. change normalizedAmount for supply and borrow
 * 4. update interest rate based on new state
 */
library LendingPool {
    using SafeMath for uint256;
    using SafeMath for int256;

    uint256 private constant SECONDS_OF_YEAR = 31536000;

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
        // update value of index at this moment in time
        updateIndex(state, asset);

        // transfer asset from user's balance account
        Transfer.transferOut(state, asset, BalancePath.getCommonPath(user), amount);

        // compute the normalized value of 'amount'
        // round floor
        uint256 normalizedAmount = Decimal.divFloor(amount, state.pool.supplyIndex[asset]);

        // mint normalizedAmount of pool token for user
        state.assets[asset].lendingPoolToken.mint(user, normalizedAmount);

        // update interest rate based on latest state
        updateInterestRate(state, asset);

        Events.logSupply(user, asset, amount);
    }

    /**
     * unsupply asset from the pool, up to initial asset supplied plus interest
     */
    function unsupply(
        Store.State storage state,
        address asset,
        uint256 amount,
        address user
    )
        internal
        returns (uint256)
    {
        // update value of index at this moment in time
        updateIndex(state, asset);

        // compute the normalized value of 'amount'
        // round ceiling
        uint256 normalizedAmount = Decimal.divCeil(amount, state.pool.supplyIndex[asset]);

        uint256 unsupplyAmount = amount;

        // check and cap the amount so user can't overdraw
        if (getNormalizedSupplyOf(state, asset, user) <= normalizedAmount) {
            normalizedAmount = getNormalizedSupplyOf(state, asset, user);
            unsupplyAmount = Decimal.mulFloor(normalizedAmount, state.pool.supplyIndex[asset]);
        }

        // transfer asset to user's balance account
        Transfer.transferIn(state, asset, BalancePath.getCommonPath(user), unsupplyAmount);
        Requires.requireCashLessThanOrEqualContractBalance(state, asset);

        // subtract normalizedAmount from the pool
        state.assets[asset].lendingPoolToken.burn(user, normalizedAmount);

        // update interest rate based on latest state
        updateInterestRate(state, asset);

        Events.logUnsupply(user, asset, unsupplyAmount);

        return unsupplyAmount;
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
        // update value of index at this moment in time
        updateIndex(state, asset);

        // compute the normalized value of 'amount'
        uint256 normalizedAmount = Decimal.divCeil(amount, state.pool.borrowIndex[asset]);

        // transfer assets to user's balance account
        Transfer.transferIn(state, asset, BalancePath.getMarketPath(user, marketID), amount);
        Requires.requireCashLessThanOrEqualContractBalance(state, asset);

        // update normalized amount borrowed by user
        state.pool.normalizedBorrow[user][marketID][asset] = state.pool.normalizedBorrow[user][marketID][asset].add(normalizedAmount);

        // update normalized amount borrowed from the pool
        state.pool.normalizedTotalBorrow[asset] = state.pool.normalizedTotalBorrow[asset].add(normalizedAmount);

        // update interest rate based on latest state
        updateInterestRate(state, asset);

        Requires.requireCollateralAccountNotLiquidatable(state, user, marketID);

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
        // update value of index at this moment in time
        updateIndex(state, asset);

        // get normalized value of amount to be repaid, which in effect take into account interest
        // (ex: if you borrowed 10, with index at 1.1, amount repaid needs to be 11 to make 11/1.1 = 10)
        uint256 normalizedAmount = Decimal.divFloor(amount, state.pool.borrowIndex[asset]);

        uint256 repayAmount = amount;

        // make sure user cannot repay more than amount owed
        if (state.pool.normalizedBorrow[user][marketID][asset] <= normalizedAmount) {
            normalizedAmount = state.pool.normalizedBorrow[user][marketID][asset];
            // repayAmount <= amount
            // because ⌈⌊a/b⌋*b⌉ <= a
            repayAmount = Decimal.mulCeil(normalizedAmount, state.pool.borrowIndex[asset]);
        }

        // transfer assets from user's balance account
        Transfer.transferOut(state, asset, BalancePath.getMarketPath(user, marketID), repayAmount);

        // update amount(normalized) borrowed by user
        state.pool.normalizedBorrow[user][marketID][asset] = state.pool.normalizedBorrow[user][marketID][asset].sub(normalizedAmount);

        // update total amount(normalized) borrowed from pool
        state.pool.normalizedTotalBorrow[asset] = state.pool.normalizedTotalBorrow[asset].sub(normalizedAmount);

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
        uint256 totalnormalizedSupply = getTotalNormalizedSupply(
            state,
            asset
        );

        uint256 actualSupply = getTotalSupply(
            state,
            asset
        ).sub(amount);

        state.pool.supplyIndex[asset] = Decimal.divFloor(
            actualSupply,
            totalnormalizedSupply
        );

        updateIndex(state, asset);

        Events.logLoss(asset, amount);
    }

    /**
     * Claim an amount from the insurance pool, in return for all the collateral.
     * Only called if an auction expired without being filled.
     */
    function claimInsurance(
        Store.State storage state,
        address asset,
        uint256 amount
    )
        internal
    {
        uint256 insuranceBalance = state.pool.insuranceBalances[asset];

        uint256 compensationAmount = SafeMath.min(amount, insuranceBalance);

        state.cash[asset] = state.cash[asset].add(amount);

        // remove compensationAmount from insurance balances
        state.pool.insuranceBalances[asset] = SafeMath.sub(
            state.pool.insuranceBalances[asset],
            compensationAmount
        );

        // all suppliers pay debt if insurance not enough
        if (compensationAmount < amount) {
            recognizeLoss(
                state,
                asset,
                amount.sub(compensationAmount)
            );
        }

        Events.logInsuranceCompensation(
            asset,
            compensationAmount
        );

    }

    function updateInterestRate(
        Store.State storage state,
        address asset
    )
        private
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
        (uint256 currentSupplyIndex, uint256 currentBorrowIndex) = getCurrentIndex(state, asset);

        uint256 _supply = getTotalSupplyWithIndex(state, asset, currentSupplyIndex);

        if (_supply == 0) {
            return (0, 0);
        }

        uint256 _borrow = getTotalBorrowWithIndex(state, asset, currentBorrowIndex).add(extraBorrowAmount);

        uint256 borrowRatio = _borrow.mul(Decimal.one()).div(_supply);

        borrowInterestRate = AssemblyCall.getBorrowInterestRate(
            address(state.assets[asset].interestModel),
            borrowRatio
        );
        require(borrowInterestRate <= 3 * Decimal.one(), "BORROW_INTEREST_RATE_EXCEED_300%");

        uint256 borrowInterest = Decimal.mulCeil(_borrow, borrowInterestRate);
        uint256 supplyInterest = Decimal.mulFloor(borrowInterest, Decimal.one().sub(state.pool.insuranceRatio));

        supplyInterestRate = Decimal.divFloor(supplyInterest, _supply);
    }

    /**
     * update the index value
     */
    function updateIndex(
        Store.State storage state,
        address asset
    )
        private
    {
        if (state.pool.indexStartTime[asset] == block.timestamp) {
            return;
        }

        (uint256 currentSupplyIndex, uint256 currentBorrowIndex) = getCurrentIndex(state, asset);

        // get the total equity value
        uint256 normalizedBorrow = state.pool.normalizedTotalBorrow[asset];
        uint256 normalizedSupply = getTotalNormalizedSupply(state, asset);

        // interest = equity value * (current index value - starting index value)
        uint256 recentBorrowInterest = Decimal.mulCeil(
            normalizedBorrow,
            currentBorrowIndex.sub(state.pool.borrowIndex[asset])
        );

        uint256 recentSupplyInterest = Decimal.mulFloor(
            normalizedSupply,
            currentSupplyIndex.sub(state.pool.supplyIndex[asset])
        );

        // the interest rate spread goes into the insurance pool
        state.pool.insuranceBalances[asset] = state.pool.insuranceBalances[asset].add(recentBorrowInterest.sub(recentSupplyInterest));

        // update the indexes
        Events.logUpdateIndex(
            asset,
            state.pool.borrowIndex[asset],
            currentBorrowIndex,
            state.pool.supplyIndex[asset],
            currentSupplyIndex
        );

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
        (uint256 currentSupplyIndex, ) = getCurrentIndex(state, asset);
        return Decimal.mulFloor(getNormalizedSupplyOf(state, asset, user), currentSupplyIndex);
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
        // the actual amount borrowed = normalizedAmount * poolIndex
        (, uint256 currentBorrowIndex) = getCurrentIndex(state, asset);
        return Decimal.mulCeil(state.pool.normalizedBorrow[user][marketID][asset], currentBorrowIndex);
    }

    function getTotalSupply(
        Store.State storage state,
        address asset
    )
        internal
        view
        returns (uint256)
    {
        (uint256 currentSupplyIndex, ) = getCurrentIndex(state, asset);
        return getTotalSupplyWithIndex(state, asset, currentSupplyIndex);
    }

    function getTotalBorrow(
        Store.State storage state,
        address asset
    )
        internal
        view
        returns (uint256)
    {
        (, uint256 currentBorrowIndex) = getCurrentIndex(state, asset);
        return getTotalBorrowWithIndex(state, asset, currentBorrowIndex);
    }

    function getTotalSupplyWithIndex(
        Store.State storage state,
        address asset,
        uint256 currentSupplyIndex
    )
        private
        view
        returns (uint256)
    {
        return Decimal.mulFloor(getTotalNormalizedSupply(state, asset), currentSupplyIndex);
    }

    function getTotalBorrowWithIndex(
        Store.State storage state,
        address asset,
        uint256 currentBorrowIndex
    )
        private
        view
        returns (uint256)
    {
        return Decimal.mulCeil(state.pool.normalizedTotalBorrow[asset], currentBorrowIndex);
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

        uint256 borrowInterestRate = state.pool.borrowAnnualInterestRate[asset]
            .mul(timeDelta).divCeil(SECONDS_OF_YEAR); // Ceil Ensure asset greater than liability

        uint256 supplyInterestRate = state.pool.supplyAnnualInterestRate[asset]
            .mul(timeDelta).div(SECONDS_OF_YEAR);

        currentBorrowIndex = Decimal.mulCeil(state.pool.borrowIndex[asset], Decimal.onePlus(borrowInterestRate));
        currentSupplyIndex = Decimal.mulFloor(state.pool.supplyIndex[asset], Decimal.onePlus(supplyInterestRate));

        return (currentSupplyIndex, currentBorrowIndex);
    }

    function getNormalizedSupplyOf(
        Store.State storage state,
        address asset,
        address user
    )
        private
        view
        returns (uint256)
    {
        return state.assets[asset].lendingPoolToken.balanceOf(user);
    }

    function getTotalNormalizedSupply(
        Store.State storage state,
        address asset
    )
        private
        view
        returns (uint256)
    {
        return state.assets[asset].lendingPoolToken.totalSupply();
    }
}