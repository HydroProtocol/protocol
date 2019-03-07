const assert = require('assert');
const { generateOrderData } = require('../sdk/sdk');
const { newContract } = require('./utils');
const TestOrder = artifacts.require('./helper/TestOrder.sol');

contract('Order', accounts => {
    let contract;

    before(async () => {
        contract = await newContract(TestOrder);
    });

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

    it('should parse out expired at from data', async () => {
        const expiredAt = Math.floor(Date.now() / 1000);
        const data = generateOrderData(0, 0, 0, expiredAt, 0, 0, 0, 0);

        let res = await contract.methods.getExpiredAtFromOrderDataPublic(data).call();
        assert.equal(expiredAt, res);
    });

    it('should parse side correctly', async () => {
        let data = generateOrderData(0, true, 0, 0, 0, 0, 0, 0);
        let res = await contract.methods.isSellPublic(data).call();
        assert.equal(true, res);

        data = generateOrderData(0, false, 0, 0, 0, 0, 0, 0);
        res = await contract.methods.isSellPublic(data).call();
        assert.equal(false, res);
    });

    it('should parse if it is a market order', async () => {
        let data = generateOrderData(0, 0, true, 0, 0, 0, 0, 0);
        let res = await contract.methods.isMarketOrderPublic(data).call();
        assert.equal(true, res);

        data = generateOrderData(0, 0, false, 0, 0, 0, 0, 0);
        res = await contract.methods.isMarketOrderPublic(data).call();
        assert.equal(false, res);
    });

    it('should parse if it is a market buy order', async () => {
        let data = generateOrderData(0, true, true, 0, 0, 0, 0, 0);
        let res = await contract.methods.isMarketBuyPublic(data).call();
        assert.equal(false, res);

        data = generateOrderData(0, true, false, 0, 0, 0, 0, 0);
        res = await contract.methods.isMarketBuyPublic(data).call();
        assert.equal(false, res);

        data = generateOrderData(0, false, false, 0, 0, 0, 0, 0);
        res = await contract.methods.isMarketBuyPublic(data).call();
        assert.equal(false, res);

        data = generateOrderData(0, false, true, 0, 0, 0, 0, 0);
        res = await contract.methods.isMarketBuyPublic(data).call();
        assert.equal(true, res);
    });

    it('should parse maker fee rate', async () => {
        let data = generateOrderData(0, 0, 0, 0, 0, 0, 0, 0);
        let res = await contract.methods.getAsMakerFeeRateFromOrderDataPublic(data).call();
        assert.equal(0, res);

        data = generateOrderData(0, 0, 0, 0, 10000, 0, 0, 0);
        res = await contract.methods.getAsMakerFeeRateFromOrderDataPublic(data).call();
        assert.equal(10000, res);
    });

    it('should parse taker fee rate', async () => {
        let data = generateOrderData(0, 0, 0, 0, 0, 0, 0, 0);
        let res = await contract.methods.getAsTakerFeeRateFromOrderDataPublic(data).call();
        assert.equal(0, res);

        data = generateOrderData(0, 0, 0, 0, 0, 10000, 0, 0);
        res = await contract.methods.getAsTakerFeeRateFromOrderDataPublic(data).call();
        assert.equal(10000, res);
    });

    it('should parse maker rebate rate', async () => {
        let data = generateOrderData(0, 0, 0, 0, 0, 0, 0, 0);
        let res = await contract.methods.getMakerRebateRateFromOrderDataPublic(data).call();
        assert.equal(0, res);

        // Any maker Rebate Rate larger than 100 will be reduced to 100.
        data = generateOrderData(0, 0, 0, 0, 0, 0, 10000, 0);
        res = await contract.methods.getMakerRebateRateFromOrderDataPublic(data).call();
        assert.equal(100, res);
    });

    it('should parse isMakerOnly', async () => {
        let data = generateOrderData(0, 0, 0, 0, 0, 0, 0, 0, true);
        let res = await contract.methods.isMakerOnlyPublic(data).call();
        assert.equal(true, res);
    });
});
