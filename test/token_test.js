const assert = require('assert');
const TestToken = artifacts.require('./helper/TestToken.sol');
const { newContract } = require('./utils');

contract('TestToken', accounts => {
    it('should return correct values', async () => {
        const testToken = await newContract(TestToken, 'TTT', 'TT', 18, { from: accounts[1] });

        const symbol = await testToken.methods.symbol().call();
        const name = await testToken.methods.name().call();
        const decimals = await testToken.methods.decimals().call();
        const creatorBalance = await testToken.methods.balanceOf(accounts[1]).call();
        const noCreatorBalance = await testToken.methods.balanceOf(accounts[2]).call();

        assert.equal('TT', symbol);
        assert.equal('TTT', name);
        assert.equal(18, decimals);
        assert.equal(creatorBalance, '1560000000000000000000000000');
        assert.equal(noCreatorBalance, '0');
    });
});
