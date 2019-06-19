require('../utils/hooks');
const { logGas } = require('../utils');
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
        const res = await hydro.approveDelegate(accounts[0], { from: accounts[1] });
        logGas(res, `hydro.approveDelegate`);

        const canMatch = await hydro.canMatchOrdersFrom(accounts[1], { from: accounts[0] });
        assert.equal(canMatch, true);

        await hydro.revokeDelegate(accounts[0], { from: accounts[1] });
        const canMatch2 = await hydro.canMatchOrdersFrom(accounts[1], { from: accounts[0] });
        assert.equal(canMatch2, false);
    });

    it('default participant', async () => {
        let isParticipant = await hydro.isParticipant(accounts[1], { from: accounts[1] });
        assert.equal(isParticipant, true);

        // exit
        let res = await hydro.exitIncentiveSystem({ from: accounts[1] });
        logGas(res, `hydro.exitIncentiveSystem`);

        isParticipant = await hydro.isParticipant(accounts[1], { from: accounts[1] });
        assert.equal(isParticipant, false);

        // join
        res = await hydro.joinIncentiveSystem({ from: accounts[1] });
        logGas(res, `hydro.joinIncentiveSystem`);

        isParticipant = await hydro.isParticipant(accounts[1], { from: accounts[1] });
        assert.equal(isParticipant, true);
    });
});
