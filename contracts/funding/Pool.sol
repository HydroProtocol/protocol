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
import "../lib/LibWhitelist.sol";
import "../lib/LibConsts.sol";

contract Pool is Store {
    using SafeMath for uint256;

    uint256 poolAnnualInterest;
    uint256 poolInterestStartTime;

    // total suppy and borrow
    mapping (address => uint256) public totalSupply;
    mapping (address => uint256) public totalBorrow;

    // token => total shares
    mapping (address => uint256) totalSupplyShares;

    // token => user => shares
    mapping (address => mapping (address => uint256)) supplyShares;

    // supply asset
    function supplyToPool(address token, uint256 amount) public {

        require(Store.balance[msg.sender][token] >= amount, "USER_BALANCE_NOT_ENOUGH");

        // first supply
        if (totalSupply[token] == 0){
            Store.balance[msg.sender][token] -= amount;
            totalSupply[token] = amount;
            supplyShares[token][msg.sender] = amount;
            totalSupplyShares[token] = amount;
            return ;
        }

        // accrue interest
        _accrueInterest(token);

        // new supply shares
        uint256 shares = amount.mul(totalSupplyShares[token]).div(totalSupply[token]);
        Store.balance[msg.sender][token] -= amount;
        totalSupply[token] = totalSupply[token].add(amount);
        supplyShares[token][msg.sender] = supplyShares[token][msg.sender].add(shares);
        totalSupplyShares[token] = totalSupplyShares[token].add(shares);

    }

    // withdraw asset
    // to avoid precision problem, input share amount instead of token amount
    function withdraw(address token, uint256 sharesAmount) public {

        uint256 tokenAmount = sharesAmount.mul(totalSupply[token]).div(totalSupplyShares[token]);
        require(sharesAmount <= supplyShares[token][msg.sender], "USER_BALANCE_NOT_ENOUGH");
        require(tokenAmount <= totalSupply[token], "POOL_BALANCE_NOT_ENOUGH");

        totalSupply[token] -= tokenAmount;
        Store.balance[msg.sender][token] += tokenAmount;
        supplyShares[token][msg.sender] -= sharesAmount;
        totalSupplyShares[token] -= sharesAmount;

    }

    // borrow and repay
    function borrow() internal returns (bytes32 loanId){

    }

    function repay(bytes32 loanId, uint256 amount) internal {
        
    }

    // get interest
    function getInterest(address token, uint256 amount) public view returns(uint256 interestRate){
        require(totalSupply[token]>=totalBorrow[token].add(amount), "BORROW_EXCEED_LIMITATION");
        return 100;
    }

    // accrue interest to totalSupply
    function _accrueInterest(address token) internal {

        // interest since last update
        uint256 interest = block.timestamp
            .sub(poolInterestStartTime)
            .mul(poolAnnualInterest)
            .div(LibConsts.getSecondsOfYear());

        // accrue interest to supply
        totalSupply[token] = totalSupply[token].add(interest);

        // update interest time
        poolInterestStartTime = block.timestamp;
    }

}