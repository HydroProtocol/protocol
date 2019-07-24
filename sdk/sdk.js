const BigNumber = require('bignumber.js');
const Hydro = artifacts.require('Hydro.sol');
const { sha3, ecrecover, hashPersonalMessage, toBuffer, pubToAddress } = require('ethereumjs-util');
const Ethers = require('ethers');

const encoder = new Ethers.utils.AbiCoder();

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
    isMakerOnly,
    balancePath
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

    if (balancePath) {
        res += '01' + addLeadingZero(new BigNumber(balancePath.marketID).toString(16), 2 * 2);
    } else {
        res += '000000';
    }

    return addTailingZero(res, 66);
};

const EIP712_DOMAIN_TYPEHASH = sha3ToHex('EIP712Domain(string name)');
const EIP712_ORDER_TYPE = sha3ToHex(
    'Order(address trader,address relayer,address baseAsset,address quoteAsset,uint256 baseAssetAmount,uint256 quoteAssetAmount,uint256 gasTokenAmount,bytes32 data)'
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
                addLeadingZero(order.baseAsset.slice(2), 64) +
                addLeadingZero(order.quoteAsset.slice(2), 64) +
                addLeadingZero(new BigNumber(order.baseAssetAmount).toString(16), 64) +
                addLeadingZero(new BigNumber(order.quoteAssetAmount).toString(16), 64) +
                addLeadingZero(new BigNumber(order.gasTokenAmount).toString(16), 64) +
                order.data.slice(2)
        )
    );
};

const ActionType = {
    Deposit: 0,
    Withdraw: 1,
    Transfer: 2,
    Borrow: 3,
    Repay: 4,
    Supply: 5,
    Unsupply: 6
};

const borrow = async (marketID, asset, amount, options) => {
    const actions = [
        {
            actionType: ActionType.Borrow,
            encodedParams: encoder.encode(
                ['uint16', 'address', 'uint256'],
                [marketID, asset, amount]
            )
        }
    ];

    return batch(actions, options);
};
const repay = async (marketID, asset, amount, options) => {
    const actions = [
        {
            actionType: ActionType.Repay,
            encodedParams: encoder.encode(
                ['uint16', 'address', 'uint256'],
                [marketID, asset, amount]
            )
        }
    ];

    return batch(actions, options);
};

const supply = async (asset, amount, options) => {
    const actions = [
        {
            actionType: ActionType.Supply,
            encodedParams: encoder.encode(['address', 'uint256'], [asset, amount])
        }
    ];

    return batch(actions, options);
};
const unsupply = async (asset, amount, options) => {
    const actions = [
        {
            actionType: ActionType.Unsupply,
            encodedParams: encoder.encode(['address', 'uint256'], [asset, amount])
        }
    ];

    return batch(actions, options);
};

const deposit = async (asset, amount, options) => {
    const actions = [
        {
            actionType: ActionType.Deposit,
            encodedParams: encoder.encode(['address', 'uint256'], [asset, amount])
        }
    ];

    return batch(actions, options);
};
const withdraw = async (asset, amount, options) => {
    const actions = [
        {
            actionType: ActionType.Withdraw,
            encodedParams: encoder.encode(['address', 'uint256'], [asset, amount])
        }
    ];

    return batch(actions, options);
};

const transfer = async (asset, fromPath, toPath, amount, options) => {
    const actions = [
        {
            actionType: ActionType.Transfer,
            encodedParams: encoder.encode(
                [
                    'address',
                    'tuple(uint8,uint16,address)',
                    'tuple(uint8,uint16,address)',
                    'uint256'
                ],
                [
                    asset,
                    [fromPath.category, fromPath.marketID, fromPath.user],
                    [toPath.category, toPath.marketID, toPath.user],
                    amount
                ]
            )
        }
    ];

    return batch(actions, options);
};

const batch = async (actions, options) => {
    const hydro = await Hydro.deployed();

    if (options) {
        return hydro.batch(actions, options);
    } else {
        return hydro.batch(actions);
    }
};

module.exports = {
    isValidSignature,
    generateOrderData,
    EIP712_DOMAIN_TYPEHASH,
    EIP712_ORDER_TYPE,
    ActionType,
    getOrderHash,
    getDomainSeparator,
    getEIP712MessageHash,
    deposit,
    withdraw,
    supply,
    unsupply,
    transfer,
    borrow,
    repay,
    batch
};
