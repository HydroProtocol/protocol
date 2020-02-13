require('../utils/hooks');

const assert = require('assert');
const { toWei, logGas } = require('../utils');
const { mine, mineAt } = require('../utils/evm');
const FeedPriceOracle = artifacts.require('./oracle/FeedPriceOracle.sol');
const PriceOracleProxy = artifacts.require('./oracle/PriceOracleProxy.sol');

contract('PriceOracleProxy', accounts => {
    let oracle;
    let ethTokenAddress = '0x000000000000000000000000000000000000000E';
    let anotherAddressForTest = '0xEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE';
    const invalidAddress = '0x0000000000000000000000000000000000000000';

    beforeEach(async () => {
        oracle = await FeedPriceOracle.new(
            [ethTokenAddress, anotherAddressForTest],
            10,
            toWei('0.1'), // 10%
            toWei('1'), // 1
            toWei('10') // 10
        );

        await oracle.feed(toWei('2'));
    });

    // successful feed & get
    it('feed price', async () => {
        res = await oracle.feed(toWei('2.02'));
        logGas(res, 'FeedPriceOracle.feed');

        assert.equal((await oracle.getPrice(ethTokenAddress)).toString(), toWei('2.02'));
        assert.equal((await oracle.getPrice(anotherAddressForTest)).toString(), toWei('2.02'));

        await assert.rejects(oracle.getPrice(invalidAddress), /ASSET_NOT_MATCH/);
    });

    it('oracle proxy with bigger decimal number', async () => {
        const fakeAssetAddress = '0x1111111111111111111111111111111111111111';
        const proxy = await PriceOracleProxy.new(
            fakeAssetAddress,
            18,
            oracle.address,
            ethTokenAddress,
            6
        );

        // price / 10**12
        assert.equal((await proxy.getPrice(fakeAssetAddress)).toString(), '2000000');
        await assert.rejects(proxy.getPrice(invalidAddress), /ASSET_NOT_MATCH/);
    });

    it('oracle proxy with smaller decimal number', async () => {
        const fakeAssetAddress = '0x1111111111111111111111111111111111111111';
        const proxy = await PriceOracleProxy.new(
            fakeAssetAddress,
            6,
            oracle.address,
            ethTokenAddress,
            18
        );

        // price * 10**12
        assert.equal(
            (await proxy.getPrice(fakeAssetAddress)).toString(),
            '2000000000000000000000000000000'
        );
    });
});
