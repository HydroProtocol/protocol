require('../hooks');
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
            baseToken: '0x0000000000000000000000000000000000000000',
            quoteToken: '0x0000000000000000000000000000000000000000',
            baseTokenAmount: 1,
            quoteTokenAmount: 1,
            data: generateOrderData(1, true, false, 0, 1, 1, 0, 1),
            gasTokenAmount: 0
        };

        const hash = getOrderHash(order);
        let cancelled = await hydro.isOrderCancelled(hash);
        assert.equal(cancelled, false);

        await hydro.cancelOrder(order, { from: order.trader });
        cancelled = await hydro.isOrderCancelled(hash);
        assert.equal(cancelled, true);
    });

    it("should abort when another try to cancel other's order", async () => {
        const order = {
            trader: accounts[0],
            relayer: '0x0000000000000000000000000000000000000000',
            baseToken: '0x0000000000000000000000000000000000000000',
            quoteToken: '0x0000000000000000000000000000000000000000',
            baseTokenAmount: 1,
            quoteTokenAmount: 1,
            data: generateOrderData(1, true, false, 0, 1, 1, 0, 1123123),
            gasTokenAmount: 0
        };

        const hash = getOrderHash(order);
        let cancelled = await hydro.isOrderCancelled(hash);
        assert.equal(cancelled, false);

        try {
            await hydro.cancelOrder(order, { from: accounts[1] });
        } catch (e) {
            assert.ok(e.message.match(/revert/));
            return;
        }

        assert(false, 'Should never get here');
    });
});
