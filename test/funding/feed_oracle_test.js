require('../utils/hooks');

const assert = require('assert');
const { toWei, logGas } = require('../utils');
const { mine, mineAt } = require('../utils/evm');
const FeedPriceOracle = artifacts.require('./oracle/FeedPriceOracle.sol');

contract('FeedPriceOracle', accounts => {
    let oracle;
    let ethTokenAddress = '0x000000000000000000000000000000000000000E';
    let anotherAddressForTest = '0xEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE';

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

        const invalidAddress = '0x0000000000000000000000000000000000000000';
        await assert.rejects(oracle.getPrice(invalidAddress), /ASSET_NOT_MATCH/);
    });

    // failed feed

    it('can not feed invalid price', async () => {
        await assert.rejects(oracle.feed(toWei('2.21')), /PRICE_CHANGE_RATE_EXCEED/);
        await assert.rejects(oracle.feed(toWei('1.79')), /PRICE_CHANGE_RATE_EXCEED/);
        await assert.rejects(oracle.feed(toWei('0')), /PRICE_MUST_GREATER_THAN_0/);
        await assert.rejects(oracle.feed(toWei('100')), /PRICE_EXCEED_MAX_LIMIT/);
        await assert.rejects(oracle.feed(toWei('0.1')), /PRICE_EXCEED_MIN_LIMIT/);
    });

    // failed get
    it('can not get price if feed expired', async () => {
        for (let i = 0; i < 11; i++) {
            await mine();
        }
        await assert.rejects(oracle.getPrice(ethTokenAddress), /PRICE_EXPIRED/);
    });

    it('set new params', async () => {
        await oracle.setParams(1, 1, 1, 1);
        assert.equal((await oracle.validBlockNumber()).toString(), '1');
        assert.equal((await oracle.maxChangeRate()).toString(), '1');
        assert.equal((await oracle.minPrice()).toString(), '1');
        assert.equal((await oracle.maxPrice()).toString(), '1');
    });
});
