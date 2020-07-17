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

contract GentleInterestModel {
    uint256 constant BASE = 10**18;

    /**
     * @param borrowRatio a decimal with 18 decimals
     */
    function polynomialInterestModel(uint256 borrowRatio) external pure returns(uint256) {
        // 0.1r + 0.2r^16 + 0.2*r^32

        // the valid range of borrowRatio is [0, 1]
        uint256 r = borrowRatio > BASE ? BASE : borrowRatio;
        uint256 r16 = r*r/BASE; // r^2
        r16 = r16*r16/BASE; // r^4
        r16 = r16*r16/BASE; // r^8
        r16 = r16*r16/BASE; // r^16
    
        return r / 10 + r16 / 5 + r16 * r16 / BASE / 5;
    }
}