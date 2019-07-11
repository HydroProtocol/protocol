require('../utils/hooks');

const assert = require('assert');
const { toWei, logGas } = require('../utils');
const { getBlockNumber, mine } = require('../utils/evm');
const FeedPriceOracle = artifacts.require('./oracle/FeedPriceOracle.sol');

contract('FeedPriceOracle', accounts => {
    let oracle;
    let ethTokenAddress = '0x0000000000000000000000000000000000000000';

    beforeEach(async () => {
        oracle = await FeedPriceOracle.new(
            ethTokenAddress,
            10,
            toWei('0.1'), // 10%
            toWei('1'), // 1
            toWei('10') // 10
        );
        await oracle.feed(toWei('2'), (await web3.eth.getBlockNumber()) + 1);
    });

    // successful feed & get
    it('feed price', async () => {
        let currentBlockNumber = await web3.eth.getBlockNumber();
        res = await oracle.feed(toWei('2.02'), currentBlockNumber + 1);
        logGas(res, 'FeedPriceOracle.feed');

        assert.equal((await oracle.getPrice(ethTokenAddress)).toString(), toWei('2.02'));
    });

    // failed feed

    it('can not feed invalid block number', async () => {
        let currentBlockNumber = await web3.eth.getBlockNumber();
        await assert.rejects(oracle.feed(toWei('2'), currentBlockNumber + 2), /BLOCKNUMBER_WRONG/);
        await assert.rejects(oracle.feed(toWei('2'), currentBlockNumber - 1), /BLOCKNUMBER_WRONG/);
    });

    it('can not feed invalid price', async () => {
        let currentBlockNumber = await web3.eth.getBlockNumber();
        await assert.rejects(
            oracle.feed(toWei('2.21'), currentBlockNumber + 1),
            /PRICE_CHANGE_RATE_EXCEED/
        );
        await assert.rejects(
            oracle.feed(toWei('1.79'), currentBlockNumber + 1),
            /PRICE_CHANGE_RATE_EXCEED/
        );
        await assert.rejects(
            oracle.feed(toWei('0'), currentBlockNumber + 1),
            /PRICE_MUST_GREATER_THAN_0/
        );
        await assert.rejects(
            oracle.feed(toWei('100'), currentBlockNumber + 1),
            /PRICE_EXCEED_MAX_LIMIT/
        );
        await assert.rejects(
            oracle.feed(toWei('0.1'), currentBlockNumber + 1),
            /PRICE_EXCEED_MIN_LIMIT/
        );
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
