require('../hooks');
const assert = require('assert');
const Hydro = artifacts.require('./Hydro.sol');

contract('Relayer', accounts => {
    let hydro;
    before(async () => {
        hydro = await Hydro.deployed();
    });

    it("relayer can't match other's orders without approve", async () => {
        const res = await hydro.canMatchOrdersFrom(accounts[1], { from: accounts[0] });
        assert.equal(res, false);
    });

    it("relayer can match other's orders with approve", async () => {
        await hydro.approveDelegate(accounts[0], { from: accounts[1] });
        const res = await hydro.canMatchOrdersFrom(accounts[1], { from: accounts[0] });
        assert.equal(res, true);

        await hydro.revokeDelegate(accounts[0], { from: accounts[1] });
        const res2 = await hydro.canMatchOrdersFrom(accounts[1], { from: accounts[0] });
        assert.equal(res2, false);
    });

    it('default participant', async () => {
        let isParticipant = await hydro.isParticipant(accounts[1], { from: accounts[1] });
        assert.equal(isParticipant, true);

        // exit
        await hydro.exitIncentiveSystem({ from: accounts[1] });
        isParticipant = await hydro.isParticipant(accounts[1], { from: accounts[1] });
        assert.equal(isParticipant, false);

        // join
        await hydro.joinIncentiveSystem({ from: accounts[1] });
        isParticipant = await hydro.isParticipant(accounts[1], { from: accounts[1] });
        assert.equal(isParticipant, true);
    });
});
