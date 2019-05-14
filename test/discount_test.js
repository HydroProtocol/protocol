const assert = require('assert');
const { getContracts } = require('./utils');

contract('Discount', accounts => {
    it('should have discount', async () => {
        const contracts = await getContracts();
        const exchange = contracts.exchange;

        // hot contract is deployed by accounts 0, so this account has many tokens.
        let res = await exchange.methods.getDiscountedRate(accounts[0]).call();
        assert.equal('60', res);

        // accounts 1 has no hot token.
        res = await exchange.methods.getDiscountedRate(accounts[1]).call();
        assert.equal('100', res);
    });

    it('can change discount', async () => {
        const contracts = await getContracts();
        const exchange = contracts.exchange;

        await exchange.methods
            .changeDiscountConfig(
                '0x040a000027106400004e205a000075305000009c404600000000000000000000'
            )
            .send({ from: accounts[0] });

        // hot contract is deployed by accounts 0, so this account has many tokens.
        const res = await exchange.methods.getDiscountedRate(accounts[0]).call();
        assert.equal('10', res);
    });

    it('cannot change discount without permissions', async () => {
        const contracts = await getContracts();
        const exchange = contracts.exchange;

        try {
            await exchange.methods
                .changeDiscountConfig(
                    '0x040a000027106400004e205a000075305000009c404600000000000000000000'
                )
                .send({ from: accounts[1] });
        } catch (e) {
            assert.ok(e.message.match(/revert/));
            return;
        }

        assert(false, 'Should never get here');
    });
});
