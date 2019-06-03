const { generateOrderData, isValidSignature, getOrderHash } = require('../../sdk/sdk');
const { fromRpcSig } = require('ethereumjs-util');

const getOrderSignature = async (order, baseToken, quoteToken) => {
    const copyedOrder = JSON.parse(JSON.stringify(order));
    copyedOrder.baseToken = baseToken;
    copyedOrder.quoteToken = quoteToken;

    const orderHash = getOrderHash(copyedOrder);

    // This depends on the client, ganache-cli/testrpc auto prefix the message header to message
    // So we have to set the method ID to 0 even through we use web3.eth.sign
    const signature = fromRpcSig(await web3.eth.sign(orderHash, order.trader));
    signature.config = `0x${signature.v.toString(16)}00` + '0'.repeat(60);
    const isValid = isValidSignature(order.trader, signature, orderHash);

    assert.equal(true, isValid);
    order.signature = signature;
    order.orderHash = orderHash;
};

const buildOrder = async (orderParam, baseTokenAddress, quoteTokenAddress) => {
    const order = {
        trader: orderParam.trader,
        relayer: orderParam.relayer,
        data: generateOrderData(
            orderParam.version,
            orderParam.side === 'sell',
            orderParam.type === 'market',
            orderParam.expiredAtSeconds,
            orderParam.asMakerFeeRate,
            orderParam.asTakerFeeRate,
            orderParam.makerRebateRate || '0',
            Math.round(Math.random() * 10000000)
        ),
        baseTokenAmount: orderParam.baseTokenAmount,
        quoteTokenAmount: orderParam.quoteTokenAmount,
        gasTokenAmount: orderParam.gasTokenAmount
    };

    await getOrderSignature(order, baseTokenAddress, quoteTokenAddress);

    return order;
};

module.exports = {
    buildOrder,
    getOrderSignature
};
