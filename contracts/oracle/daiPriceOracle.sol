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

import "../lib/Ownable.sol";
import "../lib/SafeMath.sol";
import "../interfaces/IStandardToken.sol";
import "../interfaces/IEth2Dai.sol";
import "../interfaces/IMakerDaoOracle.sol";

contract DaiPriceOracle is Ownable {
    using SafeMath for uint256;

    uint256 public price;

    IStandardToken public WETH;
    IStandardToken public DAI;
    IMakerDaoOracle public makerDaoOracle;
    IEth2Dai public OASIS;
    address public UNISWAP;

    uint256 public oasisETHAmount;
    uint256 public oasisMaxSpread;
    uint256 public uniswapMinETHAmount;

    uint256 constant ONE = 10**18;

    event UpdatePrice(uint256 newPrice);
    event UpdatePriceMannually(uint256 newPrice);

    constructor(
        address _weth,
        address _dai,
        address _makerDaoOracle,
        address _oasis,
        address _uniswap,
        uint256 _oasisETHAmount,
        uint256 _oasisMaxSpread,
        uint256 _uniswapMinETHAmount
    )
        public
    {
        WETH = IStandardToken(_weth);
        DAI = IStandardToken(_dai);
        makerDaoOracle = IMakerDaoOracle(_makerDaoOracle);

        OASIS = IEth2Dai(_oasis);
        UNISWAP = _uniswap;

        oasisETHAmount = _oasisETHAmount;
        oasisMaxSpread = _oasisMaxSpread;
        uniswapMinETHAmount = _uniswapMinETHAmount;
    }

    function getPrice(
        address _asset
    )
        public
        view
        returns (uint256)
    {
        require(_asset == 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359, "ASSET_NOT_MATCH");
        return price;
    }

    function updatePrice()
        public
        returns (uint256)
    {
        uint256 ethUsdPrice = getMakerDaoPrice();
        uint256 oasisPrice = getOasisPrice();
        if (oasisPrice > 0){
            price = ethUsdPrice.mul(ONE).div(oasisPrice);
        } else {
            uint256 uniswapPrice = getUniswapPrice();
            if (uniswapPrice > 0){
                price = ethUsdPrice.mul(ONE).div(uniswapPrice);
            } else {
                return 0;
            }
        }
        emit UpdatePrice(price);
    }

    // only enabled when oasis and uniswap both failed
    function updatePriceMannually(
        uint256 newPrice
    )
        public
        onlyOwner
        returns (uint256)
    {
        uint256 autoUpdatedPrice = updatePrice();
        if (autoUpdatedPrice == 0){
            price = newPrice;
            emit UpdatePriceMannually(newPrice);
        }
        return price;
    }

    function getOasisPrice()
        public
        view
        returns (uint256)
    {

        if (
            OASIS.isClosed()
            || !OASIS.buyEnabled()
            || !OASIS.matchingEnabled()
        ) {
            return 0;
        }

        // TODO use call to catch revert
        // https://blog.polymath.network/try-catch-in-solidity-handling-the-revert-exception-f53718f76047
        uint256 bidDai = OASIS.getBuyAmount(address(DAI), address(WETH), oasisETHAmount); // bid
        uint256 askDai = OASIS.getPayAmount(address(DAI), address(WETH), oasisETHAmount); // ask

        uint256 bidPrice = bidDai.mul(ONE).div(oasisETHAmount);
        uint256 askPrice = askDai.mul(ONE).div(oasisETHAmount);

        uint256 spread = askPrice.mul(ONE).div(bidPrice).sub(ONE);
        if (spread > oasisMaxSpread) {
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
        if (ethAmount < uniswapMinETHAmount){
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
