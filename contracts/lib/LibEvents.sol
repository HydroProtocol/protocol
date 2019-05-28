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

pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

library LibEvents {
    event Deposit(address asset, address from, address to, uint256 amount);

    function logDeposit(address asset, address from, address to, uint256 amount) internal {
        emit Deposit(asset, from, to, amount);
    }

    event Withdraw(address asset, address from, address to, uint256 amount);

    function logWithdraw(address asset, address from, address to, uint256 amount) internal {
        emit Withdraw(asset, from, to, amount);
    }

    event Transfer(address asset, address from, address to, uint256 amount);

    function logTransfer(address asset, address from, address to, uint256 amount) internal {
        emit Transfer(asset, from, to, amount);
    }
}