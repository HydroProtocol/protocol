const assert = require('assert');
const { generateOrderData } = require('../../sdk/sdk');

contract('Order', accounts => {
    it('should extract correct value from data', async () => {
        const now = 1539247438532;
        const salt = 488701836;

        const version = 1;
        const isMarketOrder = false;
        const expiredAt = Math.floor(now / 1000);
        const isSell = true;
        const makerFeeRate = 10000;
        const takerFeeRate = 50000;
        const makerRebateRate = 0;

        const data = generateOrderData(
            version,
            isSell,
            isMarketOrder,
            expiredAt,
            makerFeeRate,
            takerFeeRate,
            makerRebateRate,
            salt,
            true
        );

        // version            hex                         01
        // side               hex                         01
        // isMarketOrder      hex                         00
        // 1539247438         hex             00 5b bf 0d 4e
        // 10000              hex                      27 10
        // 50000              hex                      c3 50
        // makerRebateRate    hex                      00 00
        // 488701836          hex    00 00 00 00 1d 20 ff 8c
        // isMakerOnly        hex                         01
        assert.equal('0x010100005bbf0d4e2710c3500000000000001d20ff8c01000000000000000000', data);
    });
});
