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

import "./InterestModel.sol";
import "./PoolToken.sol";

library Pool {
    using SafeMath for uint256;

    function createPoolToken(
        Store.State storage state,
        address originAssetAddress,
        string memory name,
        string memory symbol,
        uint8 decimals
    )
        internal
    {
        require(state.pool.poolToken[originAssetAddress] == address(0), "POOL_TOKEN_ALREADY_EXIST");
        state.pool.poolToken[originAssetAddress] = address(new PoolToken(name, symbol, decimals));
    }

    // create new pool
    function createAssetPool(
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
        Types.Wallet storage wallet = state.wallets[user];

        // update index
        _updateIndex(state, asset);

        // get logic amount
        // round floor
        uint256 logicAmount = Decimal.divFloor(amount, state.pool.supplyIndex[asset]);

        // transfer asset
        wallet.balances[asset] = wallet.balances[asset].sub(amount);

        // mint pool token
        PoolToken(state.pool.poolToken[asset]).mint(user, logicAmount);

        // update interest rate
        _updateInterestRate(state, asset);
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
        Types.Wallet storage wallet = state.wallets[user];

        // update index
        _updateIndex(state, asset);

        // get logic amount
        // round ceil
        uint256 logicAmount = Decimal.divCeil(amount, state.pool.supplyIndex[asset]);
        uint256 withdrawAmount = amount;
        if (state.pool.logicSupply[user].balances[asset] < logicAmount) {
            logicAmount = state.pool.logicSupply[user].balances[asset];
            withdrawAmount = logicAmount.mul(state.pool.supplyIndex[asset]);
        }

        // transfer asset
        wallet.balances[asset] = wallet.balances[asset].add(withdrawAmount);

        // update logic amount
        PoolToken(state.pool.poolToken[asset]).burn(user, logicAmount);

        // update interest rate
        _updateInterestRate(state, asset);

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
        Types.Wallet storage wallet = state.accounts[user][marketID].wallet;

         // update index
        _updateIndex(state, asset);

        // get logic amount
        uint256 logicAmount = Decimal.divCeil(amount, state.pool.borrowIndex[asset]);

        // transfer assets
        wallet.balances[asset] = wallet.balances[asset].add(amount);

        // update logic amount
        state.pool.logicBorrow[user][marketID].balances[asset] = state.pool.logicBorrow[user][marketID].balances[asset].add(logicAmount);
        state.pool.logicTotalBorrow.balances[asset] = state.pool.logicTotalBorrow.balances[asset].add(logicAmount);

        // update interest rate
        _updateInterestRate(state, asset);
    }

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
        Types.Wallet storage wallet = state.accounts[user][marketID].wallet;

        // update index
        _updateIndex(state, asset);

        // get logic amount
        uint256 logicAmount = Decimal.divFloor(amount, state.pool.borrowIndex[asset]);
        uint256 repayAmount = amount;
        // repay all logic amount greater than debt
        if (state.pool.logicBorrow[user][marketID].balances[asset] < logicAmount){
            logicAmount = state.pool.logicBorrow[user][marketID].balances[asset];
            repayAmount = Decimal.mul(logicAmount, state.pool.borrowIndex[asset]);
        }

        // transfer assets
        wallet.balances[asset] = wallet.balances[asset].sub(repayAmount);

        // update logic amount
        state.pool.logicBorrow[user][marketID].balances[asset] = state.pool.logicBorrow[user][marketID].balances[asset].sub(logicAmount);
        state.pool.logicTotalBorrow.balances[asset] = state.pool.logicTotalBorrow.balances[asset].sub(logicAmount);

        // update interest rate
        _updateInterestRate(state, asset);

        return repayAmount;
    }

    function _updateInterestRate(
        Store.State storage state,
        address asset
    )
        internal
    {
        (uint256 borrowInterestRate, uint256 supplyInterestRate) = _getInterestRate(state, asset, 0);
        state.pool.borrowAnnualInterestRate[asset] = borrowInterestRate;
        state.pool.supplyAnnualInterestRate[asset] = supplyInterestRate;
    }

    // get interestRate
    function _getInterestRate(
        Store.State storage state,
        address asset,
        uint256 extraBorrowAmount
    )
        internal
        view
        returns (uint256 borrowInterestRate, uint256 supplyInterestRate)
    {

        uint256 _supply = _getPoolTotalSupply(state, asset);
        uint256 _borrow = _getPoolTotalBorrow(state, asset).add(extraBorrowAmount);

        require(_supply >= _borrow, "BORROW_EXCEED_LIMITATION");

        if (_supply == 0) {
            return (0, 0);
        }

        uint256 borrowRatio = _borrow.mul(Decimal.one()).div(_supply);
        borrowInterestRate = InterestModel.polynomialInterestModel(borrowRatio);
        supplyInterestRate = borrowInterestRate.mul(_borrow).div(_supply);

        return (borrowInterestRate, supplyInterestRate);
    }

    function _updateIndex(
        Store.State storage state,
        address asset
    )
        internal
    {
        (uint256 currentSupplyIndex, uint256 currentBorrowIndex) = _getPoolCurrentIndex(state, asset);
        state.pool.supplyIndex[asset] = currentSupplyIndex;
        state.pool.borrowIndex[asset] = currentBorrowIndex;
        state.pool.indexStartTime[asset] = block.timestamp;
    }

    function _getPoolSupplyOf(
        Store.State storage state,
        address asset,
        address user
    )
        internal
        view
        returns (uint256)
    {
        (uint256 currentSupplyIndex, ) = _getPoolCurrentIndex(state, asset);
        return Decimal.mul(state.pool.logicSupply[user].balances[asset], currentSupplyIndex);
    }

    function _getPoolBorrowOf(
        Store.State storage state,
        address asset,
        address user,
        uint16 marketID
    )
        internal
        view
        returns (uint256)
    {
        (, uint256 currentBorrowIndex) = _getPoolCurrentIndex(state, asset);
        return Decimal.mul(state.pool.logicBorrow[user][marketID].balances[asset], currentBorrowIndex);
    }

    function _getPoolTotalSupply(
        Store.State storage state,
        address asset
    )
        internal
        view
        returns (uint256)
    {
        (uint256 currentSupplyIndex, ) = _getPoolCurrentIndex(state, asset);
        return Decimal.mul(state.pool.logicTotalSupply.balances[asset], currentSupplyIndex);
    }

    function _getPoolTotalBorrow(
        Store.State storage state,
        address asset
    )
        internal
        view
        returns (uint256)
    {
        (, uint256 currentBorrowIndex) = _getPoolCurrentIndex(state, asset);
        return Decimal.mul(state.pool.logicTotalBorrow.balances[asset], currentBorrowIndex);
    }

    function _getPoolCurrentIndex(
        Store.State storage state,
        address asset
    )
        internal
        view
        returns (uint256 currentSupplyIndex, uint256 currentBorrowIndex)
    {
         uint256 borrowInterestRate = state.pool.borrowAnnualInterestRate[asset]
            .mul(block.timestamp.sub(state.pool.indexStartTime[asset]))
            .div(Consts.SECONDS_OF_YEAR());
         uint256 supplyInterestRate = state.pool.supplyAnnualInterestRate[asset]
            .mul(block.timestamp.sub(state.pool.indexStartTime[asset]))
            .div(Consts.SECONDS_OF_YEAR());

        currentBorrowIndex = Decimal.mul(state.pool.borrowIndex[asset], Decimal.onePlus(borrowInterestRate));
        currentSupplyIndex = Decimal.mul(state.pool.supplyIndex[asset], Decimal.onePlus(supplyInterestRate));

        return (currentSupplyIndfex, currentBorrowIndex);
    }

}