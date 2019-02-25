const assert = require('assert');
const { getContracts } = require('./utils');
const { EIP712_DOMAIN_TYPEHASH, EIP712_ORDER_TYPE, getDomainSeparator } = require('../sdk/sdk');

contract('Order', () => {
    let exchange;

    before(async () => {
        const contracts = await getContracts();
        exchange = contracts.exchange;
    });

    it('domain type hash', async () => {
        const domainHashInContract = await exchange.methods.EIP712_DOMAIN_TYPEHASH().call();
        assert.equal(EIP712_DOMAIN_TYPEHASH, domainHashInContract);
    });

    it('domain separator', async () => {
        const computedDomainSeparator = getDomainSeparator();
        const domainSeparator = await exchange.methods.DOMAIN_SEPARATOR().call();
        assert.equal(computedDomainSeparator, domainSeparator);
    });

    it('order type hash', async () => {
        const domainHashInContract = await exchange.methods.EIP712_ORDER_TYPE().call();
        assert.equal(EIP712_ORDER_TYPE, domainHashInContract);
    });
});
