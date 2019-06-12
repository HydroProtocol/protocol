require('../utils/hooks');
const assert = require('assert');
const TestSafeERC20 = artifacts.require('./helper/TestSafeERC20.sol');
const TestToken = artifacts.require('./helper/TestToken.sol');
const { maxUint256 } = require('../utils');

contract('TestSafeERC20', accounts => {
    it('should be able to transfer reasonable amount', async () => {
        const tokenHolder = await TestSafeERC20.new();
        const tokenAddress = await tokenHolder.tokenAddress();
        const token = await TestToken.at(tokenAddress);

        const totalBalance = (await token.balanceOf(tokenHolder.address)).toString();

        assert(totalBalance !== '0');
        assert.equal(await token.balanceOf(accounts[0]), '0');

        await tokenHolder.transfer(accounts[0], '200');
        assert.equal(await token.balanceOf(accounts[0]), '200');
    });

    it('should revert if try to transfer a huge amount', async () => {
        const tokenHolder = await TestSafeERC20.new();
        const tokenAddress = await tokenHolder.tokenAddress();
        const token = await TestToken.at(tokenAddress);

        const totalBalance = (await token.balanceOf(tokenHolder.address)).toString();

        assert(totalBalance !== '0');
        assert.equal(await token.balanceOf(accounts[0]), '0');

        await assert.rejects(tokenHolder.transfer(accounts[0], maxUint256), /TOKEN_TRANSFER_ERROR/);
        assert.equal(await token.balanceOf(accounts[0]), '0');
    });
});
