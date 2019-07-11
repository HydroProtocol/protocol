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
import "../interfaces/IStandardToken.sol";
import "../interfaces/IEth2Dai.sol";
import "../interfaces/IMakerDaoOracle.sol";

/**
 * Dai USD price oracle for mainnet
 */
contract DaiPriceOracle {
    using SafeMath for uint256;

    uint256 public price;

    uint256 constant ONE = 10**18;

    IMakerDaoOracle public constant makerDaoOracle = IMakerDaoOracle(0x729D19f657BD0614b4985Cf1D82531c67569197B);
    IStandardToken public constant DAI = IStandardToken(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359);
    IEth2Dai public constant Eth2Dai = IEth2Dai(0x39755357759cE0d7f32dC8dC45414CCa409AE24e);

    address public constant UNISWAP = 0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 public constant eth2daiETHAmount = 10 ether;
    uint256 public constant eth2daiMaxSpread = 2 * ONE / 100; // 2.00%
    uint256 public constant uniswapMinETHAmount = 2000 ether;

    event UpdatePrice(uint256 newPrice);

    function getPrice(
        address asset
    )
        public
        view
        returns (uint256)
    {
        require(asset == address(DAI), "ASSET_NOT_MATCH");
        return price;
    }

    function updatePrice()
        public
        returns (uint256)
    {
        uint256 ethUsdPrice = getMakerDaoPrice();
        uint256 eth2daiPrice = getEth2DaiPrice();

        if (eth2daiPrice > 0) {
            price = ethUsdPrice.mul(ONE).div(eth2daiPrice);
        } else {
            uint256 uniswapPrice = getUniswapPrice();
            if (uniswapPrice > 0) {
                price = ethUsdPrice.mul(ONE).div(uniswapPrice);
            } else {
                revert("UPDATE_DAI_PRICE_FAILED");
            }
        }

        emit UpdatePrice(price);
    }

    function getEth2DaiPrice()
        public
        view
        returns (uint256)
    {
        if (Eth2Dai.isClosed() || !Eth2Dai.buyEnabled() || !Eth2Dai.matchingEnabled()) {
            return 0;
        }

        uint256 bidDai = Eth2Dai.getBuyAmount(address(DAI), WETH, eth2daiETHAmount);
        uint256 askDai = Eth2Dai.getPayAmount(address(DAI), WETH, eth2daiETHAmount);

        uint256 bidPrice = bidDai.mul(ONE).div(eth2daiETHAmount);
        uint256 askPrice = askDai.mul(ONE).div(eth2daiETHAmount);

        uint256 spread = askPrice.mul(ONE).div(bidPrice).sub(ONE);

        if (spread > eth2daiMaxSpread) {
            return 0;
        } else {
            return bidPrice.add(askPrice).div(2);
        }
    }

    function getUniswapPrice()
        internal
        view
        returns (uint256)
    {
        uint256 ethAmount = UNISWAP.balance;
        uint256 daiAmount = DAI.balanceOf(UNISWAP);
        uint256 uniswapPrice = daiAmount.mul(10**18).div(ethAmount);

        if (ethAmount < uniswapMinETHAmount) {
            return 0;
        } else {
            return uniswapPrice;
        }
    }

    function getMakerDaoPrice()
        internal
        view
        returns (uint256)
    {
        (bytes32 value, ) = makerDaoOracle.peek();
        return uint256(value);
    }

}
