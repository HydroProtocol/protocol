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
import "../lib/InterestModel.sol";
import "./PoolToken.sol";

library Pool {
    using SafeMath for uint256;

    function createPoolToken(
        Store.State storage state,
        address originTokenAddress,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) internal {
        state.pool.poolToken[originTokenAddress] = address(new PoolToken(name, symbol, decimals));
    }

    // create new pool
    function createAssetPool(
        Store.State storage state,
        address token
    ) internal {
        state.pool.borrowIndex[token] = Decimal.one();
        state.pool.supplyIndex[token] = Decimal.one();
        state.pool.indexStartTime[token] = block.timestamp;
    }

    // four asset operation: supply, withdraw, borrow, repay
    // 1. update index first to get the right logic amount
    // 2. transfer asset
    // 3. change logic supply and logic borrow
    // 4. update interest rate

    function supply(
        Store.State storage state,
        Types.Wallet storage wallet,
        address token,
        uint256 amount,
        address user
    ) internal {

        // update index
        _updateIndex(state, token);

        // get logic amount
        // round floor
        uint256 logicAmount = Decimal.divFloor(amount, state.pool.supplyIndex[token]);

        // transfer asset
        wallet.balances[token] = wallet.balances[token].sub(amount);

        // update logic amount
        state.pool.logicSupply[user].balances[token] = state.pool.logicSupply[user].balances[token].add(logicAmount);
        state.pool.logicTotalSupply.balances[token] = state.pool.logicTotalSupply.balances[token].add(logicAmount);

        // update interest rate
        _updateInterestRate(state, token);
    }

    function withdraw(
        Store.State storage state,
        Types.Wallet storage wallet,
        address token,
        uint256 amount,
        address user
    )
        internal
        returns(uint256)
    {

        // update index
        _updateIndex(state, token);

        // get logic amount
        // round ceil
        uint256 logicAmount = Decimal.divCeil(amount, state.pool.supplyIndex[token]);
        uint256 withdrawAmount = amount;
        if (state.pool.logicSupply[user].balances[token] < logicAmount) {
            logicAmount = state.pool.logicSupply[user].balances[token];
            withdrawAmount = logicAmount.mul(state.pool.supplyIndex[token]);
        }

        // transfer asset
        wallet.balances[token] = wallet.balances[token].add(withdrawAmount);

        // update logic amount
        state.pool.logicSupply[user].balances[token] = state.pool.logicSupply[user].balances[token].sub(logicAmount);
        state.pool.logicTotalSupply.balances[token] = state.pool.logicTotalSupply.balances[token].sub(logicAmount);

        // update interest rate
        _updateInterestRate(state, token);

        return withdrawAmount;
    }

    function borrow(
        Store.State storage state,
        Types.Wallet storage wallet,
        address token,
        uint256 amount,
        uint16 marketID,
        address user
    ) internal {

         // update index
        _updateIndex(state, token);

        // get logic amount
        uint256 logicAmount = Decimal.divCeil(amount, state.pool.borrowIndex[token]);

        // transfer assets
        wallet.balances[token] = wallet.balances[token].add(amount);

        // update logic amount
        state.pool.logicBorrow[user][marketID].balances[token] = state.pool.logicBorrow[user][marketID].balances[token].add(logicAmount);
        state.pool.logicTotalBorrow.balances[token] = state.pool.logicTotalBorrow.balances[token].add(logicAmount);

        // update interest rate
        _updateInterestRate(state, token);
    }

    function repay(
        Store.State storage state,
        Types.Wallet storage wallet,
        address token,
        uint256 amount,
        uint16 marketID,
        address user
    )
        internal
        returns(uint256)
    {

        // update index
        _updateIndex(state, token);

        // get logic amount
        uint256 logicAmount = Decimal.divFloor(amount, state.pool.borrowIndex[token]);
        uint256 repayAmount = amount;
        // repay all logic amount greater than debt
        if (state.pool.logicBorrow[user][marketID].balances[token] < logicAmount){
            logicAmount = state.pool.logicBorrow[user][marketID].balances[token];
            repayAmount = Decimal.mul(logicAmount, state.pool.borrowIndex[token]);
        }

        // transfer assets
        wallet.balances[token] = wallet.balances[token].sub(repayAmount);

        // update logic amount
        state.pool.logicBorrow[user][marketID].balances[token] = state.pool.logicBorrow[user][marketID].balances[token].sub(logicAmount);
        state.pool.logicTotalBorrow.balances[token] = state.pool.logicTotalBorrow.balances[token].sub(logicAmount);

        // update interest rate
        _updateInterestRate(state, token);

        return repayAmount;
    }

    // mint and redeem
    function transferLogicSupply(
        Store.State storage state,
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        state.pool.logicSupply[from].balances[token] = state.pool.logicSupply[from].balances[token].sub(value);
        state.pool.logicSupply[to].balances[token] = state.pool.logicSupply[to].balances[token].add(value);
    }

    function mintPoolToken(
        Store.State storage state,
        address token,
        address user,
        uint256 value
    ) internal {
        require(state.pool.poolToken[token] != address(0), "POOL_TOKEN_NOT_EXIST");
        require(msg.sender == user, "SENDER_MUST_BE_USER");
        transferLogicSupply(state, token, user, state.pool.poolToken[token], value);
        PoolToken(state.pool.poolToken[token]).mint(user, value);
    }

    function redeemPoolToken(
        Store.State storage state,
        address token,
        address user,
        uint256 value
    ) internal {
        require(msg.sender == state.pool.poolToken[token], "SENDER_MUST_BE_POOL_TOKEN");
        transferLogicSupply(state, token, state.pool.poolToken[token], user, value);
    }

    function _updateInterestRate(
        Store.State storage state,
        address token
    ) internal {
        (uint256 borrowInterestRate, uint256 supplyInterestRate) = _getInterestRate(state, token, 0);
        state.pool.borrowAnnualInterestRate[token] = borrowInterestRate;
        state.pool.supplyAnnualInterestRate[token] = supplyInterestRate;
    }

    // get interestRate
    function _getInterestRate(
        Store.State storage state,
        address token,
        uint256 extraBorrowAmount
    )
        internal
        view
        returns(uint256 borrowInterestRate, uint256 supplyInterestRate)
    {

        uint256 _supply = _getPoolTotalSupply(state, token);
        uint256 _borrow = _getPoolTotalBorrow(state, token).add(extraBorrowAmount);

        require(_supply >= _borrow, "BORROW_EXCEED_LIMITATION");

        if (_supply == 0) {
            return (0, 0);
        }

        uint256 borrowRatio = _borrow.mul(Decimal.one()).div(_supply);
        borrowInterestRate = InterestModel.polynomialInterestModel(borrowRatio);
        supplyInterestRate = borrowInterestRate.mul(_borrow).div(_supply);

        return (borrowInterestRate, supplyInterestRate);
    }

    function _updateIndex(Store.State storage state, address token) internal {
        (uint256 currentSupplyIndex, uint256 currentBorrowIndex) = _getPoolCurrentIndex(state, token);
        state.pool.supplyIndex[token] = currentSupplyIndex;
        state.pool.borrowIndex[token] = currentBorrowIndex;
        state.pool.indexStartTime[token] = block.timestamp;
    }

    function _getPoolSupply(Store.State storage state, address token, address user) internal view returns (uint256){
        (uint256 currentSupplyIndex, ) = _getPoolCurrentIndex(state, token);
        return Decimal.mul(state.pool.logicSupply[user].balances[token], currentSupplyIndex);
    }

    function _getPoolBorrow(Store.State storage state, address token, address user, uint16 marketID) internal view returns (uint256){
        (, uint256 currentBorrowIndex) = _getPoolCurrentIndex(state, token);
        return Decimal.mul(state.pool.logicBorrow[user][marketID].balances[token], currentBorrowIndex);
    }

    function _getPoolTotalSupply(Store.State storage state, address token) internal view returns (uint256){
        (uint256 currentSupplyIndex, ) = _getPoolCurrentIndex(state, token);
        return Decimal.mul(state.pool.logicTotalSupply.balances[token], currentSupplyIndex);
    }

    function _getPoolTotalBorrow(Store.State storage state, address token) internal view returns (uint256){
        (, uint256 currentBorrowIndex) = _getPoolCurrentIndex(state, token);
        return Decimal.mul(state.pool.logicTotalBorrow.balances[token], currentBorrowIndex);
    }

    function _getPoolCurrentIndex(Store.State storage state, address token) internal view returns (uint256 currentSupplyIndex, uint256 currentBorrowIndex){
         uint256 borrowInterestRate = state.pool.borrowAnnualInterestRate[token]
            .mul(block.timestamp.sub(state.pool.indexStartTime[token]))
            .div(Consts.SECONDS_OF_YEAR());
         uint256 supplyInterestRate = state.pool.supplyAnnualInterestRate[token]
            .mul(block.timestamp.sub(state.pool.indexStartTime[token]))
            .div(Consts.SECONDS_OF_YEAR());

        currentBorrowIndex = Decimal.mul(state.pool.borrowIndex[token], Decimal.onePlus(borrowInterestRate));
        currentSupplyIndex = Decimal.mul(state.pool.supplyIndex[token], Decimal.onePlus(supplyInterestRate));

        return (currentSupplyIndex, currentBorrowIndex);
    }

}