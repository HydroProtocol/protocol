pragma solidity 0.4.24;

import "../lib/LibOrder.sol";

// Test wrapper

contract TestOrder is LibOrder {
    function getExpiredAtFromOrderDataPublic(bytes32 data) public pure returns (uint256) {
        return getExpiredAtFromOrderData(data);
    }

    function isSellPublic(bytes32 data) public pure returns (bool) {
        return isSell(data);
    }

    function isMarketOrderPublic(bytes32 data) public pure returns (bool) {
        return isMarketOrder(data);
    }

    function isMarketBuyPublic(bytes32 data) public pure returns (bool) {
        return isMarketBuy(data);
    }

    function getAsMakerFeeRateFromOrderDataPublic(bytes32 data) public pure returns (uint256) {
        return getAsMakerFeeRateFromOrderData(data);
    }

    function getAsTakerFeeRateFromOrderDataPublic(bytes32 data) public pure returns (uint256) {
        return getAsTakerFeeRateFromOrderData(data);
    }

    function getMakerRebateRateFromOrderDataPublic(bytes32 data) public pure returns (uint256) {
        return getMakerRebateRateFromOrderData(data);
    }
}