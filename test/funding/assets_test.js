const assert = require('assert');
const { getFundingContracts } = require('../utils');

contract('Order', accounts => {
    let funding;

    beforeEach(async () => {
        const contracts = await getFundingContracts();
        funding = contracts.funding;
    });

    const getAllAssetsCount = async () => {
        return await funding.methods.getAllAssetsCount().call();
    };

    it('no assets at first', async () => {
        assert.equal(0, await getAllAssetsCount());
    });

    const tokenAddress = '0x0000000000000000000000000000000000000001';

    it('owner can add asset', async () => {
        const res = await funding.methods
            .addAsset(tokenAddress, 1)
            .send({ from: accounts[0], gasLimit: 10000000 });
        console.log('add asset gas cost:', res.gasUsed);

        assert.equal(1, await getAllAssetsCount());
    });

    it('only owner can add asset', async () => {
        try {
            const res = await funding.methods
                .addAsset(tokenAddress, 1)
                .send({ from: accounts[1], gasLimit: 10000000 });
            console.log('add asset gas cost:', res.gasUsed);
        } catch (e) {
            assert.equal(0, await getAllAssetsCount());
            assert.ok(e.message.match(/NOT_OWNER/));
            return;
        }

        assert(false, 'Should never get here');
    });

    it("can't add duplicated asset", async () => {
        await funding.methods
            .addAsset(tokenAddress, 1)
            .send({ from: accounts[0], gasLimit: 10000000 });

        assert.equal(1, await getAllAssetsCount());
        try {
            await funding.methods
                .addAsset(tokenAddress, 1)
                .send({ from: accounts[0], gasLimit: 10000000 });
        } catch (e) {
            assert.ok(e.message.match(/TOKEN_IS_ALREADY_EXIST/));
            assert.equal(1, await getAllAssetsCount());
            return;
        }

        assert(false, 'Should never get here');
    });
});
