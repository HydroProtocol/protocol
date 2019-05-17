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

import "../lib/SafeMath.sol";
import "../interfaces/EIP20Interface.sol";
import "../interfaces/DepositProxyInterface.sol";
import "./ProxyCaller.sol";

contract Collateral is ProxyCaller {
    using SafeMath for uint256;

    mapping (address => mapping(address => uint256)) public colleterals;

    event DepositCollateral(address token, address user, uint256 amount);
    event WithdrawCollateral(address token, address user, uint256 amount);

    function depositCollateral(address token, address user, uint256 amount) internal {
        DepositProxyInterface(proxyAddress).depositFor(token, user, user, amount);
        depositCollateralFromProxy(token, user, amount);
    }

    function depositCollateralFromProxy(address token, address user, uint256 amount) internal {
        address payable currentContract = address(uint160(address(this)));
        DepositProxyInterface(proxyAddress).withdrawTo(token, user, currentContract, amount);
        colleterals[token][user] = colleterals[token][user].add(amount);

        emit DepositCollateral(token, user, amount);
    }

    // function withdrawCollateralToProxy(address token, address user, uint256 amount) internal {
    //     colleterals[token][user] = colleterals[token][user].sub(amount);
    //     if (token == address(0)) {
    //         DepositProxyInterface(proxyAddress).depositFor.value(amount)(token, address(this), user, amount);
    //     } else {
    //         if (EIP20Interface(token).allowance(address(this), proxyAddress) < amount) {
    //             EIP20Interface(token).approve(proxyAddress, 0xf0000000000000000000000000000000000000000000000000000000000000);
    //         }
    //         DepositProxyInterface(proxyAddress).depositFor(token, address(this), user, amount);
    //     }

    //     emit WithdrawCollateral(token, user, amount);
    // }

    // function withdrawCollateral(address token, address payable user, uint256 amount) internal {
    //     withdrawCollateralToProxy(token, user, amount);
    //     DepositProxyInterface(proxyAddress).withdrawTo(token, user, user, amount);
    // }
}