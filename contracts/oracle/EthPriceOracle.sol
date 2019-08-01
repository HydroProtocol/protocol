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

import "../interfaces/IMakerDaoOracle.sol";

/**
 * Eth USD price oracle for mainnet
 */
contract EthPriceOracle {

    IMakerDaoOracle public constant makerDaoOracle = IMakerDaoOracle(0x729D19f657BD0614b4985Cf1D82531c67569197B);

    function getPrice(
        address _asset
    )
        external
        view
        returns (uint256)
    {
        require(_asset == address(0), "ASSET_NOT_MATCH");
        (bytes32 value, bool has) = makerDaoOracle.peek();
        require(has, "MAKER_ORACLE_OFFLINE");
        return uint256(value);
    }

}