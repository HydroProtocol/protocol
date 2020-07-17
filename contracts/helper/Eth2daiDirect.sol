/**
 *Submitted for verification at Etherscan.io on 2018-03-16
*/

pragma solidity ^0.5.8;

contract Eth2daiInterface {
    // sellAllAmount(ERC20 pay_gem, uint pay_amt, ERC20 buy_gem, uint min_fill_amount)
    function sellAllAmount(address, uint, address, uint) public returns (uint);
}

contract TokenInterface {
    function balanceOf(address) public returns (uint);
    function allowance(address, address) public returns (uint);
    function approve(address, uint) public;
    function transfer(address,uint) public returns (bool);
    function transferFrom(address, address, uint) public returns (bool);
    function deposit() public payable;
    function withdraw(uint) public;
}

contract Eth2daiDirect {

    Eth2daiInterface public constant eth2dai = Eth2daiInterface(0x39755357759cE0d7f32dC8dC45414CCa409AE24e);
    TokenInterface public constant wethToken = TokenInterface(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    TokenInterface public constant daiToken = TokenInterface(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359);

    function marketBuyEth(
        uint256 payDaiAmount,
        uint256 minBuyEthAmount
    )
        public
    {
        daiToken.transferFrom(msg.sender, address(this), payDaiAmount);
        uint256 fillAmount = eth2dai.sellAllAmount(address(daiToken), payDaiAmount, address(wethToken), minBuyEthAmount);
        wethToken.withdraw(fillAmount);
        msg.sender.transfer(fillAmount);
    }

    function marketSellEth(
        uint256 payEthAmount,
        uint256 minBuyDaiAmount
    )
        public
        payable
    {
        require(msg.value == payEthAmount, "MSG_VALUE_NOT_MATCH");
        wethToken.deposit.value(msg.value)();
        uint256 fillAmount = eth2dai.sellAllAmount(address(wethToken), payEthAmount, address(daiToken), minBuyDaiAmount);
        daiToken.transfer(msg.sender, fillAmount);
    }

    function() external payable {
        require(msg.sender == address(wethToken), "CONTRACT_NOT_PAYABLE");
    }
}