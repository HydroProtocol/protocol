pragma solidity 0.5.8;

contract OracleInterface {
    function getTokenPriceInEther(address token) public view returns (uint256);
}