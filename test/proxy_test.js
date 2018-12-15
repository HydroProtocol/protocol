const assert = require('assert');
const TestToken = artifacts.require('./helper/TestToken.sol');
const { newContract, getContracts, getWeb3 } = require('./utils');
const BigNumber = require('bignumber.js');

contract('Proxy', accounts => {
    let proxy;

    before(async () => {
        const contracts = await getContracts();
        proxy = contracts.proxy;

        // add creator into whitelist
        await proxy.methods.addAddress(accounts[1]).send({ from: accounts[0] });
    });

    it('should transfer 10000 token a to b', async () => {
        const testToken = await newContract(TestToken, 'TestToken', 'TT', 18, { from: accounts[1] });

        // give accounts 2 some tokens
        await testToken.methods.transfer(accounts[2], '30000').send({ from: accounts[1] });
        assert.equal('30000', await testToken.methods.balanceOf(accounts[2]).call());

        // accounts 2 approve
        await testToken.methods.approve(proxy._address, '10000').send({ from: accounts[2] });
        assert.equal('10000', await testToken.methods.allowance(accounts[2], proxy._address).call());

        // transfer from
        await proxy.methods
            .transferFrom(testToken._address, accounts[2], accounts[3], '10000')
            .send({ from: accounts[1] });

        assert.equal('20000', await testToken.methods.balanceOf(accounts[2]).call());
        assert.equal('10000', await testToken.methods.balanceOf(accounts[3]).call());
    });

    it('deposit / withdraw', async () => {
        let balanceInContract;

        const newWeb3 = getWeb3();
        balanceInContract = await proxy.methods.balances(accounts[7]).call();
        assert.equal(balanceInContract, '0');

        const balance = new BigNumber(2).times(10 ** 18).toString();

        await newWeb3.eth.sendTransaction({
            from: accounts[7],
            to: proxy._address,
            value: balance
        });

        balanceInContract = await proxy.methods.balances(accounts[7]).call();
        assert.equal(balanceInContract, balance);

        await proxy.methods.withdrawEther(balance).send({ from: accounts[7] });

        balanceInContract = await proxy.methods.balances(accounts[7]).call();
        assert.equal(balanceInContract, '0');
    });

    it('revert when transferring token the account does not have', async () => {
        const testToken = await newContract(TestToken, 'TestToken', 'TT', 18, { from: accounts[1] });

        // give accounts 2 some tokens
        await testToken.methods.transfer(accounts[2], '30000').send({ from: accounts[1] });
        assert.equal('30000', await testToken.methods.balanceOf(accounts[2]).call());

        // accounts 2 approve more than owned
        await testToken.methods.approve(proxy._address, '100000').send({ from: accounts[2] });
        assert.equal('100000', await testToken.methods.allowance(accounts[2], proxy._address).call());

        // transfer more than account owns
        try {
            await proxy.methods
                .transferFrom(testToken._address, accounts[2], accounts[3], '40000')
                .send({ from: accounts[1] });
        } catch (e) {
            assert.ok(e.message.match(/out of gas/));
            return;
        }

        assert(false, 'Should not get here');
    });

    it('revert when withdrawing funds account does not have', async () => {
        let balanceInContract;

        const newWeb3 = getWeb3();
        balanceInContract = await proxy.methods.balances(accounts[7]).call();
        assert.equal(balanceInContract, '0');

        const balance = new BigNumber(2).times(10 ** 18).toString();

        await newWeb3.eth.sendTransaction({
            from: accounts[7],
            to: proxy._address,
            value: balance
        });

        balanceInContract = await proxy.methods.balances(accounts[7]).call();
        assert.equal(balanceInContract, balance);

        try {
            await proxy.methods.withdrawEther(new BigNumber(balance).times(2).toString()).send({ from: accounts[7] });
        } catch (e) {
            assert.ok(e.message.match(/revert/));
        }

        await proxy.methods.withdrawEther(balance).send({ from: accounts[7] });

        balanceInContract = await proxy.methods.balances(accounts[7]).call();
        assert.equal(balanceInContract, '0');
    });
});
