const assert = require('assert');
const { getFundingContracts } = require('../utils');
const {
    EIP712_DOMAIN_TYPEHASH,
    EIP712_FUNDING_ORDER_TYPE,
    getDomainSeparator
} = require('../../sdk/sdk');

contract('Order', () => {
    let funding;

    before(async () => {
        const contracts = await getFundingContracts();
        funding = contracts.funding;
    });

    it('domain type hash', async () => {
        const domainHashInContract = await funding.methods.EIP712_DOMAIN_TYPEHASH().call();
        assert.equal(EIP712_DOMAIN_TYPEHASH, domainHashInContract);
    });

    it('domain separator', async () => {
        const computedDomainSeparator = getDomainSeparator();
        const domainSeparator = await funding.methods.DOMAIN_SEPARATOR().call();
        assert.equal(computedDomainSeparator, domainSeparator);
    });

    it('order type hash', async () => {
        const domainHashInContract = await funding.methods.EIP712_FUNDING_ORDER_TYPE().call();
        assert.equal(EIP712_FUNDING_ORDER_TYPE, domainHashInContract);
    });
});
