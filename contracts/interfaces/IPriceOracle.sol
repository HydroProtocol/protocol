pragma solidity 0.5.8;

interface IPriceOracle {
    /** return USD price of token, uint is 10**18 */
    function getPrice(address asset) external view returns (uint256);
}