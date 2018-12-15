pragma solidity 0.4.24;

import "../lib/LibMath.sol";

// Test wrapper

contract TestMath is LibMath {
    function isRoundingErrorPublic(uint256 a, uint256 b, uint256 c) public pure returns (bool) {
        return isRoundingError(a, b, c);
    }

    function getPartialAmountFloorPublic(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        return getPartialAmountFloor(a, b, c);
    }
    
    function minPublic(uint256 a, uint256 b) public pure returns (uint256) {
        return min(a, b);
    }
}