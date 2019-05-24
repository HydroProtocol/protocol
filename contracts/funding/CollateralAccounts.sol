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
import "./Loans.sol";
import "./ProxyCaller.sol";
import "./OracleCaller.sol";
import "./Assets.sol";
import "./Auctions.sol";

contract CollateralAccounts is OracleCaller, Loans, Assets, Auctions {
    using SafeMath for uint256;

    // collateral count
    uint256 public collateralAccountCount = 1;

    // a map to save all Margin collateral accounts
    mapping(uint256 => CollateralAccount) public allCollateralAccounts;

    // a map to save all funding collateral accounts
    mapping(address => uint256) public userDefaultCollateralAccounts;

    // a user deposit tokens to default collateral account
    event DepositCollateral(address token, address user, uint256 amount);

    // a user withdraw tokens from default collateral account
    event WithdrawCollateral(address token, address user, uint256 amount);

    struct CollateralAccount {
        address owner;
        mapping(address => uint256) assetAmounts;
        uint256[] loanIDs;
    }

    function newCollateralAccount(address user) internal pure returns (CollateralAccount memory account) {
        account.owner = user;
    }

    function findOrCreateDefaultCollateralAccount(address user) internal returns (CollateralAccount storage) {
        uint256 id = userDefaultCollateralAccounts[user];

        if (id == 0) {
            id = createCollateralAccount(user);
            userDefaultCollateralAccounts[user] = id;
        }

        return allCollateralAccounts[id];
    }

    function createCollateralAccount(address user) internal returns (uint256) {
        uint256 id = collateralAccountCount++;
        allCollateralAccounts[id] = newCollateralAccount(user);
        return id;
    }

    // deposit collateral for default account
    function depositCollateral(address token, address user, uint256 amount) public {
        if (amount == 0) {
            return;
        }

        DepositProxyInterface(proxyAddress).depositFor(token, user, user, amount);
        depositCollateralFromProxy(token, user, amount);
    }

    function depositCollateralFromProxy(address token, address user, uint256 amount) public {
        if (amount == 0) {
            return;
        }

        address payable currentContract = address(uint160(address(this)));
        DepositProxyInterface(proxyAddress).withdrawTo(token, user, currentContract, amount);

        CollateralAccount storage account = findOrCreateDefaultCollateralAccount(user);
        account.assetAmounts[token] = account.assetAmounts[token].add(amount);

        emit DepositCollateral(token, user, amount);
    }

    function collateralBalanceOf(address token, address user) public view returns (uint256) {
        uint256 id = userDefaultCollateralAccounts[user];

        if (id == 0) {
            return 0;
        }

        return allCollateralAccounts[id].assetAmounts[token];
    }

    // to allow proxy transfer ether into this current contract
    // TODO: is there a way to prevent a user from depositing unexpectedly??
    function () external payable {}

    struct CollateralAccountState {
        bool       liquidable;
        uint256[]  collateralAssetAmounts;
        Loan[]     loans;
        uint256[]  loanValues;
        uint256    loansTotalValue;
        uint256    collateralsTotalValue;
    }

    function getCollateralAccountState(uint256 id)
        public view
        returns (CollateralAccountState memory state)
    {
        CollateralAccount storage account = allCollateralAccounts[id];

        state.collateralAssetAmounts = new uint256[](allAssets.length);

        for (uint256 i = 0; i < allAssets.length; i++) {
            address tokenAddress = allAssets[i].tokenAddress;
            uint256 amount = account.assetAmounts[tokenAddress];

            state.collateralAssetAmounts[i] = amount;
            state.collateralsTotalValue = state.collateralsTotalValue.add(getAssetAmountValue(tokenAddress, amount));
        }

        state.loans = getLoansByIDs(account.loanIDs);

        if (state.loans.length <= 0) {
            return state;
        }

        state.loanValues = new uint256[](state.loans.length);

        for (uint256 i = 0; i < state.loans.length; i++) {
            // TODO get total loan debt
            (uint256 totalInterest, uint256 _relayerFee) = calculateLoanInterest(state.loans[i], state.loans[i].amount); // TODO use left amount
            _relayerFee;

            state.loanValues[i] = getAssetAmountValue(state.loans[i].asset, state.loans[i].amount.add(totalInterest));  // TODO use left amount
            state.loansTotalValue = state.loansTotalValue.add(state.loanValues[i]);
        }

        state.liquidable = state.collateralsTotalValue < state.loansTotalValue.mul(150).div(100);
    }


    function getAssetAmountValue(address asset, uint256 amount) internal view returns (uint256) {
        uint256 price = getTokenPriceInEther(asset);
        return price.mul(amount).div(ORACLE_PRICE_BASE);
    }

    function liquidateCollateralAccounts(uint256[] memory accountIDs) public {
        for( uint256 i = 0; i < accountIDs.length; i++ ) {
            liquidateCollateralAccount(accountIDs[i]);
        }
    }

    function isCollateralAccountLiquidable(uint256 id) public view returns (bool) {
        CollateralAccountState memory state = getCollateralAccountState(id);
        return state.liquidable;
    }

    function liquidateCollateralAccount(uint256 id) public returns (bool) {
        CollateralAccount storage account = allCollateralAccounts[id];
        CollateralAccountState memory state = getCollateralAccountState(id);

        if (!state.liquidable) {
            return false;
        }

        // storage changes
        for (uint256 i = 0; i < state.loans.length; i++ ) {
            createAuction(state.loans[i], state.loanValues[i], state.loansTotalValue, state.collateralAssetAmounts);
            unlinkLoanAndAccount(state.loans[i].id, id);
        }

        // confiscate all collaterals
        // transfer all user collateral to liquidatingAssets;
        for (uint256 i = 0; i < allAssets.length; i++) {
            Asset memory asset = allAssets[i];

            // TODO separate by user ??
            liquidatingAssets[asset.tokenAddress] = liquidatingAssets[asset.tokenAddress].add(account.assetAmounts[asset.tokenAddress]);
            account.assetAmounts[asset.tokenAddress] = 0;
        }

        return true;
    }

    function unlinkLoanAndAccount(uint256 loanID, uint256 accountID) internal {
        CollateralAccount storage account = allCollateralAccounts[accountID];

        for (uint256 i = 0; i < account.loanIDs.length; i++){
            if (account.loanIDs[i] == loanID) {
                account.loanIDs[i] = account.loanIDs[account.loanIDs.length-1];
                delete account.loanIDs[account.loanIDs.length - 1];
                account.loanIDs.length--;
                break;
            }
        }
    }
}