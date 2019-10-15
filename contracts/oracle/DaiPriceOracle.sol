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
import "../lib/Ownable.sol";
import "../interfaces/IStandardToken.sol";
import "../interfaces/IEth2Dai.sol";
import "../interfaces/IMakerDaoOracle.sol";

/**
 * Dai USD price oracle for mainnet
 */
contract DaiPriceOracle is Ownable{
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

    uint256 public minPrice;
    uint256 public maxPrice;

    constructor (
        uint256 _minPrice,
        uint256 _maxPrice
    )
        public
    {
        require(_minPrice <= _maxPrice, "WRONG_PARAMS");
        minPrice = _minPrice;
        maxPrice = _maxPrice;
    }

    function getPrice(
        address asset
    )
        external
        view
        returns (uint256)
    {
        require(asset == address(DAI), "ASSET_NOT_MATCH");
        return price;
    }

    function adminSetPrice(
        uint256 _price
    )
        external
        onlyOwner
    {
        if (!updatePrice()){
            price = _price;
        }

        emit UpdatePrice(price);
    }

    function adminSetParams(
        uint256 _minPrice,
        uint256 _maxPrice
    )
        external
        onlyOwner
    {
        require(_minPrice <= _maxPrice, "WRONG_PARAMS");
        minPrice = _minPrice;
        maxPrice = _maxPrice;
    }

    function updatePrice()
        public
        onlyOwner
        returns (bool)
    {
        uint256 _price = peek();

        if (_price == 0) {
            return false;
        }

        if (_price == price) {
            return true;
        }

        if (_price > maxPrice) {
            _price = maxPrice;
        } else if (_price < minPrice) {
            _price = minPrice;
        }

        price = _price;
        emit UpdatePrice(price);

        return true;
    }

    function peek()
        public
        view
        returns (uint256 _price)
    {
        uint256 makerDaoPrice = getMakerDaoPrice();

        if (makerDaoPrice == 0) {
            return _price;
        }

        uint256 eth2daiPrice = getEth2DaiPrice();

        if (eth2daiPrice > 0) {
            _price = makerDaoPrice.mul(ONE).div(eth2daiPrice);
            return _price;
        }

        uint256 uniswapPrice = getUniswapPrice();

        if (uniswapPrice > 0) {
            _price = makerDaoPrice.mul(ONE).div(uniswapPrice);
            return _price;
        }

        return _price;
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
        public
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
        public
        view
        returns (uint256)
    {
        (bytes32 value, bool has) = makerDaoOracle.peek();

        if (has) {
            return uint256(value);
        } else {
            return 0;
        }
    }
}
