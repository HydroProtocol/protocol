pragma solidity 0.5.8;

contract DepositProxyInterface {
    event Deposit(address token, address account, uint256 amount, uint256 balance);
    event Withdraw(address token, address account, uint256 amount, uint256 balance);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // deposit token need approve first.
    function deposit(address token, uint256 amount) public;

    function depositFor(address token, address from, address to, uint256 amount) public payable;

    function withdraw(address token, uint256 amount) external;

    function withdrawTo(address token, address from, address payable to, uint256 amount) public;

    function balanceOf(address token, address account) public view returns (uint256);
}