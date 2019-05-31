const assert = require('assert');
const Hydro = artifacts.require('./Hydro.sol');
const { getDomainSeparator } = require('../../sdk/sdk');

contract('Exchange Hash', () => {
    it('domain separator', async () => {
        const hydro = await Hydro.deployed();
        const computedDomainSeparator = getDomainSeparator();
        const domainSeparator = await hydro.DOMAIN_SEPARATOR();
        assert.equal(computedDomainSeparator, domainSeparator);
    });
});
