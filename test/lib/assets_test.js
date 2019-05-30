const {
    getHydroContract
} = require('../utils.js');
const assert = require('assert');

contract('Assets', accounts => {
    let hydro;

    before(async () => {
        hydro = await getHydroContract();
    });

    it('test', async () => {
        assert.equal(await hydro.methods.getAllAssetsCount().call(), 0);
    });
});