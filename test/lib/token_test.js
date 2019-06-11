const assert = require('assert');
const TestToken = artifacts.require('../helper/TestToken.sol');

contract('TestToken', accounts => {
    it('should return correct values', async () => {
        const testToken = await TestToken.new('TTT', 'TT', 18, { from: accounts[1] });

        const symbol = await testToken.symbol();
        const name = await testToken.name();
        const decimals = await testToken.decimals();
        const creatorBalance = await testToken.balanceOf(accounts[1]);
        const noCreatorBalance = await testToken.balanceOf(accounts[2]);

        assert.equal('TT', symbol);
        assert.equal('TTT', name);
        assert.equal('18', decimals.toString());
        assert.equal(creatorBalance, '1560000000000000000000000000');
        assert.equal(noCreatorBalance, '0');
    });
});
