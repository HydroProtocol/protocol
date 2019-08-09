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
import "../lib/Ownable.sol";

/**
 * Eth USD price oracle for mainnet
 */
contract EthPriceOracle is Ownable {

    uint256 public sparePrice;
    uint256 public sparePriceBlockNumber;

    IMakerDaoOracle public constant makerDaoOracle = IMakerDaoOracle(0x729D19f657BD0614b4985Cf1D82531c67569197B);

    event PriceFeed(
        uint256 price,
        uint256 blockNumber
    );

    function getPrice(
        address _asset
    )
        external
        view
        returns (uint256)
    {
        require(_asset == 0x000000000000000000000000000000000000000E, "ASSET_NOT_MATCH");
        (bytes32 value, bool has) = makerDaoOracle.peek();
        if (has) {
            return uint256(value);
        } else {
            require(block.number - sparePriceBlockNumber <= 500, "ORACLE_OFFLINE");
            return sparePrice;
        }
    }

    function feed(
        uint256 newSparePrice,
        uint256 blockNumber
    )
        external
        onlyOwner
    {
        require(newSparePrice > 0, "PRICE_MUST_GREATER_THAN_0");
        require(blockNumber <= block.number && blockNumber >= sparePriceBlockNumber, "BLOCKNUMBER_WRONG");
        sparePrice = newSparePrice;
        sparePriceBlockNumber = blockNumber;

        emit PriceFeed(newSparePrice, blockNumber);
    }

}