const assert = require('assert');
const { getFundingContracts } = require('../utils');

contract('Order', () => {
    let funding;

    before(async () => {
        const contracts = await getFundingContracts();
        funding = contracts.funding;
    });

    const getAllAssetsCount = async () => {
        return await funding.methods.getAllAssetsCount().call();
    }

    it('no assets at first', async () => {
        assert.equal(0, await getAllAssetsCount());
    });
});
