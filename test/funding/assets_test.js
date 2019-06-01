const Hydro = artifacts.require('./Hydro.sol');
const assert = require('assert');

contract('Assets', accounts => {
    let hydro;

    before(async () => {
        hydro = await Hydro.deployed();
    });

    it('no assets at first', async () => {
        assert.equal(await hydro.getAllAssetsCount.call(), 0);
    });

    const tokenAddress = "0x0000000000000000000000000000000000000001";
    const oracleAddress = "0x0000000000000000000000000000000000000002";
    const collateralRate = 15000;

    it('owner can add asset', async () => {
        const addAssetRes = await hydro.addAsset(tokenAddress, collateralRate, oracleAddress, {
            from: accounts[0],
            gas: 200000
        });
        console.log('add asset gas cost:', addAssetRes.receipt.gasUsed);
        assert.equal(await hydro.getAllAssetsCount.call(), 1);
        const assetID = await hydro.getAssetID.call(tokenAddress);
        assert.equal(assetID, 0);
        const assetInfo = await hydro.getAssetInfo.call(assetID);
        assert.equal(assetInfo["tokenAddress"], tokenAddress);
        assert.equal(assetInfo["oracleAddress"], oracleAddress);
        assert.equal(assetInfo["collateralRate"].toNumber(), collateralRate);
    });

    it('only onwner can add asset', async () => {
        try {
            await hydro.addAsset(tokenAddress, collateralRate, oracleAddress, {
                from: accounts[1],
                gas: 200000
            });
        } catch (e) {
            assert.equal(await hydro.getAllAssetsCount.call(), 1);
            assert.ok(e.message.match(/NOT_OWNER/));
            return;
        }
        assert(false, 'Should never get here');
    });

    it('can not add duplicated asset', async () => {
        try {
            await hydro.addAsset(tokenAddress, collateralRate, oracleAddress, {
                from: accounts[0],
                gas: 200000
            });
        } catch (e) {
            assert.equal(await hydro.getAllAssetsCount.call(), 1);
            assert.ok(e.message.match(/TOKEN_IS_ALREADY_EXIST/));
            return;
        }
        assert(false, 'Should never get here');
    });
});