pragma solidity 0.5.8;

import "./StandardToken.sol";

contract TestToken is StandardToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint public totalSupply = 1560000000 * 10**18;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        balances[msg.sender] = totalSupply;
    }
}