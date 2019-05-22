const BigNumber = require('bignumber.js');
const { sha3, ecrecover, hashPersonalMessage, toBuffer, pubToAddress } = require('ethereumjs-util');

const sha3ToHex = message => {
    return '0x' + sha3(message).toString('hex');
};

const addLeadingZero = (str, length) => {
    let len = str.length;
    return '0'.repeat(length - len) + str;
};

const addTailingZero = (str, length) => {
    let len = str.length;
    return str + '0'.repeat(length - len);
};

const isValidSignature = (account, signature, message) => {
    let pubkey;
    const v = parseInt(signature.config.slice(2, 4), 16);
    const method = parseInt(signature.config.slice(4, 6), 16);
    if (method === 0) {
        pubkey = ecrecover(
            hashPersonalMessage(toBuffer(message)),
            v,
            toBuffer(signature.r),
            toBuffer(signature.s)
        );
    } else if (method === 1) {
        pubkey = ecrecover(toBuffer(message), v, toBuffer(signature.r), toBuffer(signature.s));
    } else {
        throw new Error('wrong method');
    }

    const address = '0x' + pubToAddress(pubkey).toString('hex');
    return address.toLowerCase() == account.toLowerCase();
};

const generateOrderData = (
    version,
    isSell,
    isMarket,
    expiredAtSeconds,
    asMakerFeeRate,
    asTakerFeeRate,
    makerRebateRate,
    salt,
    isMakerOnly
) => {
    let res = '0x';
    res += addLeadingZero(new BigNumber(version).toString(16), 2);
    res += isSell ? '01' : '00';
    res += isMarket ? '01' : '00';
    res += addLeadingZero(new BigNumber(expiredAtSeconds).toString(16), 5 * 2);
    res += addLeadingZero(new BigNumber(asMakerFeeRate).toString(16), 2 * 2);
    res += addLeadingZero(new BigNumber(asTakerFeeRate).toString(16), 2 * 2);
    res += addLeadingZero(new BigNumber(makerRebateRate).toString(16), 2 * 2);
    res += addLeadingZero(new BigNumber(salt).toString(16), 8 * 2);
    res += isMakerOnly ? '01' : '00';

    return addTailingZero(res, 66);
};

const generateFundingOrderData = (side, expiredAt, loanDuration, interestRate, feeRate, salt) => {
    // * ╔════════════════════╤═══════════════════════════════════════════════════════════╗
    // * ║                    │ length(bytes)   desc                                      ║
    // * ╟────────────────────┼───────────────────────────────────────────────────────────╢
    // * ║ version            │ 1               order version                             ║
    // * ║ side               │ 1               0: lend, 1: borrow                        ║
    // * ║ expiredAt          │ 5               order expiration timestamp                ║
    // * ║ loanDuration       │ 5               loan duration timestamp                   ║
    // * ║ interestRate       │ 2               interest rate (base 10,000)               ║
    // * ║ feeRate            │ 2               fee rate (base 100,00)                    ║
    // * ║ salt               │ rest            salt                                      ║
    // * ╚════════════════════╧═══════════════════════════════════════════════════════════╝
    let res = '0x01';
    res += side == 'lend' ? '00' : '01';
    res += addLeadingZero(new BigNumber(expiredAt).toString(16), 5 * 2);
    res += addLeadingZero(new BigNumber(loanDuration).toString(16), 5 * 2);
    res += addLeadingZero(new BigNumber(interestRate).toString(16), 2 * 2);
    res += addLeadingZero(new BigNumber(feeRate).toString(16), 2 * 2);
    res += addLeadingZero(new BigNumber(salt).toString(16), 8 * 2);

    return addTailingZero(res, 66);
};

const EIP712_DOMAIN_TYPEHASH = sha3ToHex('EIP712Domain(string name)');
const EIP712_ORDER_TYPE = sha3ToHex(
    'Order(address trader,address relayer,address baseToken,address quoteToken,uint256 baseTokenAmount,uint256 quoteTokenAmount,uint256 gasTokenAmount,bytes32 data)'
);

const EIP712_FUNDING_ORDER_TYPE = sha3ToHex(
    'Order(address owner,address relayer,address asset,uint256 amount,bytes32 data)'
);

const getDomainSeparator = () => {
    return sha3ToHex(EIP712_DOMAIN_TYPEHASH + sha3ToHex('Hydro Protocol').slice(2));
};

const getEIP712MessageHash = message => {
    return sha3ToHex('0x1901' + getDomainSeparator().slice(2) + message.slice(2), {
        encoding: 'hex'
    });
};

const getOrderHash = order => {
    return getEIP712MessageHash(
        sha3ToHex(
            EIP712_ORDER_TYPE +
                addLeadingZero(order.trader.slice(2), 64) +
                addLeadingZero(order.relayer.slice(2), 64) +
                addLeadingZero(order.baseToken.slice(2), 64) +
                addLeadingZero(order.quoteToken.slice(2), 64) +
                addLeadingZero(new BigNumber(order.baseTokenAmount).toString(16), 64) +
                addLeadingZero(new BigNumber(order.quoteTokenAmount).toString(16), 64) +
                addLeadingZero(new BigNumber(order.gasTokenAmount).toString(16), 64) +
                order.data.slice(2)
        )
    );
};

const getFundingOrderHash = order => {
    const a =
        EIP712_FUNDING_ORDER_TYPE +
        addLeadingZero(order.owner.slice(2), 64) +
        addLeadingZero(order.relayer.slice(2), 64) +
        addLeadingZero(order.asset.slice(2), 64) +
        addLeadingZero(new BigNumber(order.amount).toString(16), 64) +
        order.data.slice(2);
    console.log(sha3ToHex(a));
    return getEIP712MessageHash(
        sha3ToHex(
            EIP712_FUNDING_ORDER_TYPE +
                addLeadingZero(order.owner.slice(2), 64) +
                addLeadingZero(order.relayer.slice(2), 64) +
                addLeadingZero(order.asset.slice(2), 64) +
                addLeadingZero(new BigNumber(order.amount).toString(16), 64) +
                order.data.slice(2)
        )
    );
};

module.exports = {
    isValidSignature,
    getFundingOrderHash,
    generateOrderData,
    EIP712_DOMAIN_TYPEHASH,
    EIP712_FUNDING_ORDER_TYPE,
    EIP712_ORDER_TYPE,
    getOrderHash,
    generateFundingOrderData,
    getDomainSeparator,
    getEIP712MessageHash
};
