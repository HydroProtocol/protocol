const assert = require('assert');
const { getContracts } = require('./utils');

contract('Relayer', accounts => {
    let exchange;

    beforeEach(async () => {
        const contracts = await getContracts();
        exchange = contracts.exchange;
    });

    it("relayer can't match other's orders without approve", async () => {
        const res = await exchange.methods.canMatchOrdersFrom(accounts[1]).call({ from: accounts[0] });
        assert.equal(false, res);
    });

    it("relayer can match other's orders with approve", async () => {
        await exchange.methods.approveDelegate(accounts[0]).send({ from: accounts[1] });
        const res = await exchange.methods.canMatchOrdersFrom(accounts[1]).call({ from: accounts[0] });
        assert.equal(true, res);

        await exchange.methods.revokeDelegate(accounts[0]).send({ from: accounts[1] });
        const res2 = await exchange.methods.canMatchOrdersFrom(accounts[1]).call({ from: accounts[0] });
        assert.equal(false, res2);
    });

    it('default participant', async () => {
        let isParticipant = await exchange.methods.isParticipant(accounts[1]).call({ from: accounts[1] });
        assert.equal(true, isParticipant);

        // exit
        await exchange.methods.exitIncentiveSystem().send({ from: accounts[1] });
        isParticipant = await exchange.methods.isParticipant(accounts[1]).call({ from: accounts[1] });
        assert.equal(false, isParticipant);

        // join
        await exchange.methods.joinIncentiveSystem().send({ from: accounts[1] });
        isParticipant = await exchange.methods.isParticipant(accounts[1]).call({ from: accounts[1] });
        assert.equal(true, isParticipant);
    });
});
