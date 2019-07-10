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

pragma solidity 0.5.8;

import "../lib/SafeMath.sol";

/**
 * Standard ERC20 token
 */
contract StandardToken {
    using SafeMath for uint256;

    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) internal allowed;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /**
    * @dev transfer token for a specified address
    * @param to The address to transfer to.
    * @param amount The amount to be transferred.
    */
    function transfer(
        address to,
        uint256 amount
    )
        public
        returns (bool)
    {
        require(to != address(0), "TO_ADDRESS_IS_EMPTY");
        require(amount <= balances[msg.sender], "BALANCE_NOT_ENOUGH");

        balances[msg.sender] = balances[msg.sender].sub(amount);
        balances[to] = balances[to].add(amount);
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address owner) public view returns (uint256 balance) {
        return balances[owner];
    }

    /**
    * @dev Transfer tokens from one address to another
    * @param from address The address which you want to send tokens from
    * @param to address The address which you want to transfer to
    * @param amount uint256 the amount of tokens to be transferred
    */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        returns (bool)
    {
        require(to != address(0), "TO_ADDRESS_IS_EMPTY");
        require(amount <= balances[from], "BALANCE_NOT_ENOUGH");
        require(amount <= allowed[from][msg.sender], "ALLOWANCE_NOT_ENOUGH");

        balances[from] = balances[from].sub(amount);
        balances[to] = balances[to].add(amount);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(amount);
        emit Transfer(from, to, amount);
        return true;
    }

    /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    * @param spender The address which will spend the funds.
    * @param amount The amount of tokens to be spent.
    */
    function approve(
        address spender,
        uint256 amount
    )
        public
        returns (bool)
    {
        allowed[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
    * @dev Function to check the amount of tokens that an owner allowed to a spender.
    * @param owner address The address which owns the funds.
    * @param spender address The address which will spend the funds.
    * @return A uint256 specifying the amount of tokens still available for the spender.
    */
    function allowance(
        address owner,
        address spender
    )
        public
        view
        returns (uint256)
    {
        return allowed[owner][spender];
    }
}