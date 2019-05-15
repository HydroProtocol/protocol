pragma solidity 0.5.8;

import "../exchange/Order.sol";

// Test wrapper

contract TestOrder is Order {
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

    function isMakerOnlyPublic(bytes32 data) public pure returns (bool) {
        return isMakerOnly(data);
    }
}