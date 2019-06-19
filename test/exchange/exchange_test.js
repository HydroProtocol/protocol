require('../utils/hooks');
const { logGas } = require('../utils');
const assert = require('assert');
const { generateOrderData, getOrderHash } = require('../../sdk/sdk');
const Hydro = artifacts.require('./Hydro.sol');

contract('CancelOrder', accounts => {
    let hydro;

    before(async () => {
        hydro = await Hydro.deployed();
    });

    it('should cancel order', async () => {
        const order = {
            trader: accounts[0],
            relayer: '0x0000000000000000000000000000000000000000',
            baseAsset: '0x0000000000000000000000000000000000000000',
            quoteAsset: '0x0000000000000000000000000000000000000000',
            baseAssetAmount: 1,
            quoteAssetAmount: 1,
            data: generateOrderData(1, true, false, 0, 1, 1, 0, 1, false),
            gasTokenAmount: 0
        };

        const hash = getOrderHash(order);
        let cancelled = await hydro.isOrderCancelled(hash);
        assert.equal(cancelled, false);

        const res = await hydro.cancelOrder(order, { from: order.trader });
        logGas(res, 'hydro.cancelOrder');

        cancelled = await hydro.isOrderCancelled(hash);
        assert.equal(cancelled, true);
    });

    it("should abort when another try to cancel other's order", async () => {
        const order = {
            trader: accounts[0],
            relayer: '0x0000000000000000000000000000000000000000',
            baseAsset: '0x0000000000000000000000000000000000000000',
            quoteAsset: '0x0000000000000000000000000000000000000000',
            baseAssetAmount: 1,
            quoteAssetAmount: 1,
            data: generateOrderData(1, true, false, 0, 1, 1, 0, 1123123, false),
            gasTokenAmount: 0
        };

        const hash = getOrderHash(order);
        let cancelled = await hydro.isOrderCancelled(hash);
        assert.equal(cancelled, false);

        await assert.rejects(hydro.cancelOrder(order, { from: accounts[1] }), /revert/);
    });
});
