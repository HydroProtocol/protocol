require('../utils/hooks');
const StableCoinInterestModel = artifacts.require('StableCoinInterestModel.sol');
const CommonInterestModel = artifacts.require('CommonInterestModel.sol');
const { toWei } = require('../utils');
const assert = require('assert');
const BigNumber = require('bignumber.js');

contract('StableCoinInterestModel', accounts => {
    let model;
    const base = 10 ** 18;

    before(async () => {
        model = await StableCoinInterestModel.new();
    });

    it('should match', async () => {
        assert.equal(await model.polynomialInterestModel(0), toWei('0.05'));

        assert.equal(await model.polynomialInterestModel(toWei('1')), toWei('1'));
        assert.equal(await model.polynomialInterestModel(toWei('1.1')), toWei('1'));

        assert.equal(await model.polynomialInterestModel(toWei('0.8')), toWei('0.306114688'));

        assert.equal(
            await model.polynomialInterestModel(toWei('0.05')),
            toWei('0.050002500021484375')
        );

        assert.equal(
            await model.polynomialInterestModel(toWei('0.31')),
            toWei('0.053740993007059255')
        );
    });

    const calc = r => {
        const base = '1000000000000000000';

        const r1 = new BigNumber(r).times(base);
        const r2 = new BigNumber(
            r1
                .times(r1)
                .div(base)
                .toFixed(0, 1)
        );
        const r4 = new BigNumber(
            r2
                .times(r2)
                .div(base)
                .toFixed(0, 1)
        );
        const r8 = new BigNumber(
            r4
                .times(r4)
                .div(base)
                .toFixed(0, 1)
        );

        // return 0.05 * 10 ** 18 + (r4 * 4) / 10 + (r8 * 55) / 100;
        const result = new BigNumber(0.05)
            .times(base)
            .plus(r4.times(4).div(10))
            .plus(r8.times(55).div(100))
            .toFixed(0, 1);

        console.log(`r = ${r}, interest rate = ${result}`);

        return result;
    };

    // test all interest rate
    it.skip('show interest values', async () => {
        for (let i = 0; i <= 1000; i++) {
            const borrowRate = new BigNumber(i).div('1000');

            assert.equal(await model.polynomialInterestModel(toWei(borrowRate)), calc(borrowRate));
        }
    });
});

contract('CommonInterestModel', accounts => {
    let model;
    const base = 10 ** 18;

    before(async () => {
        model = await CommonInterestModel.new();
    });

    it('should match', async () => {
        assert.equal(await model.polynomialInterestModel(0), toWei('0'));

        assert.equal(await model.polynomialInterestModel(toWei('1')), toWei('1'));

        assert.equal(await model.polynomialInterestModel(toWei('1.1')), toWei('1'));

        assert.equal(await model.polynomialInterestModel(toWei('0.8')), toWei('0.300777472'));

        assert.equal(
            await model.polynomialInterestModel(toWei('0.05')),
            toWei('0.000003437517578125')
        );

        assert.equal(
            await model.polynomialInterestModel(toWei('0.31')),
            toWei('0.005117745596684845')
        );
    });

    const calc = r => {
        const base = '1000000000000000000';

        const r1 = new BigNumber(r).times(base);
        const r2 = new BigNumber(
            r1
                .times(r1)
                .div(base)
                .toFixed(0, 1)
        );
        const r4 = new BigNumber(
            r2
                .times(r2)
                .div(base)
                .toFixed(0, 1)
        );
        const r8 = new BigNumber(
            r4
                .times(r4)
                .div(base)
                .toFixed(0, 1)
        );

        // return 0.55 * r**4 + 0.45 * r**8;
        const result = r4
            .times(55)
            .div(100)
            .plus(r8.times(45).div(100))
            .toFixed(0, 1);

        console.log(`r = ${r}, interest rate = ${result}`);

        return result;
    };

    // test all interest rate
    it.skip('show interest values', async () => {
        for (let i = 0; i <= 1000; i++) {
            const borrowRate = new BigNumber(i).div('1000');

            assert.equal(await model.polynomialInterestModel(toWei(borrowRate)), calc(borrowRate));
        }
    });
});
