pragma solidity 0.5.8;

interface IOracle {
    /** return USD price of token, uint is 10**18 */
    function getPrice(address token) external view returns (uint256);
}