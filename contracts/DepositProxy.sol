pragma solidity 0.5.8;

import "./lib/SafeMath.sol";
import "./lib/LibWhitelist.sol";
import "./lib/LibSafeERC20Transfer.sol";

/**
 * The DepositProxy contract is a deposit/withdraw escrow for Hydro Hybrid Exchange.
 * Hydro Hybrid Exchange can use it to exchange ether or tokens.
 */
contract DepositProxy is LibWhitelist, LibSafeERC20Transfer {
    using SafeMath for uint256;

    mapping (address => mapping (address => uint))  public  balances;

    event Deposit(address token, address account, uint256 amount, uint256 balance);
    event Withdraw(address token, address account, uint256 amount, uint256 balance);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // deposit token need approve first.
    function depositToken(address token, uint256 amount) public {
        balances[token][msg.sender] = balances[token][msg.sender].add(amount);
        safeTransferFrom(token, msg.sender, address(this), amount);
        emit Deposit(token, msg.sender, amount, balances[token][msg.sender]);
    }

    function deposit() public payable {
        balances[address(0)][msg.sender] = balances[address(0)][msg.sender].add(msg.value);
        emit Deposit(address(0), msg.sender, msg.value, balances[address(0)][msg.sender]);
    }

    function withdraw(address token, uint256 amount) public {
        require(balances[token][msg.sender] >= amount, "BALANCE_NOT_ENOUGH");

        balances[token][msg.sender] = balances[token][msg.sender].sub(amount);
        if (token == address(0)) {
            msg.sender.transfer(amount);
        } else {
            safeTransfer(token, msg.sender, amount);
        }
        emit Withdraw(token, msg.sender, amount, balances[token][msg.sender]);
    }

    function () external payable {
        deposit();
    }

    function balanceOf(address token, address account) public view returns (uint256) {
        return balances[token][account];
    }

    /// @dev Invoking transferFrom.
    /// @param token Address of token to transfer.
    /// @param from Address to transfer token from.
    /// @param to Address to transfer token to.
    /// @param amount Amount of token to transfer.
    function transferFrom(address token, address from, address to, uint256 amount)
      external
      onlyAddressInWhitelist
    {
        require(balances[token][from] >= amount, "TRANSFER_BALANCE_NOT_ENOUGH");

        balances[token][from] = balances[token][from].sub(amount);
        balances[token][to] = balances[token][to].add(amount);

        emit Transfer(from, to, amount);
    }
}