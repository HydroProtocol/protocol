const { generateOrderData, isValidSignature, getOrderHash } = require('../../sdk/sdk');
const { fromRpcSig } = require('ethereumjs-util');

const getOrderSignature = async (order, baseAsset, quoteAsset) => {
    const copyedOrder = JSON.parse(JSON.stringify(order));
    copyedOrder.baseAsset = baseAsset;
    copyedOrder.quoteAsset = quoteAsset;

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

const buildOrder = async (orderParam, baseAssetAddress, quoteAssetAddress) => {
    if (orderParam.balancePath) {
        assert.equal(orderParam.balancePath.user, orderParam.trader);
    }

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
            Math.round(Math.random() * 10000000),
            false,
            orderParam.balancePath
        ),
        baseAssetAmount: orderParam.baseAssetAmount,
        quoteAssetAmount: orderParam.quoteAssetAmount,
        gasTokenAmount: orderParam.gasTokenAmount
    };

    await getOrderSignature(order, baseAssetAddress, quoteAssetAddress);

    return order;
};

module.exports = {
    buildOrder,
    getOrderSignature
};
