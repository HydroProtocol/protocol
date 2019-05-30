const Hydro = artifacts.require('./Hydro.sol');
const assert = require('assert');

contract('Assets', accounts => {
    let hydro;

    before(async () => {
        hydro = await Hydro.deployed();
    });

    it('test', async () => {
        assert.equal(true, true);
    });
});
