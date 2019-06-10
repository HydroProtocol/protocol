pragma solidity 0.5.8;

import "../lib/Math.sol";

// Test wrapper

contract TestMath {
    function isRoundingError(uint256 a, uint256 b, uint256 c) public pure returns (bool) {
        return Math.isRoundingError(a, b, c);
    }

    function getPartialAmountFloor(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        return Math.getPartialAmountFloor(a, b, c);
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return Math.min(a, b);
    }
}