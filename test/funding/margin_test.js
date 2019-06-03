const assert = require('assert');
const { snapshot, revert } = require('../utils/evm');
const Hydro = artifacts.require('./Hydro.sol');
const TestToken = artifacts.require('./helper/TestToken.sol');
const { createAssets } = require('../utils/assets');
const { toWei, pp } = require('../utils');
const { generateOrderData, isValidSignature, getOrderHash } = require('../../sdk/sdk');
const { fromRpcSig } = require('ethereumjs-util');

contract('Margin', accounts => {
    let hydro;
    let snapshotID;

    before(async () => {
        hydro = await Hydro.deployed();
    });

    beforeEach(async () => {
        snapshotID = await snapshot();
    });

    afterEach(async () => {
        await revert(snapshotID);
    });

    const relayer = accounts[9];

    const u1 = accounts[4];
    const u2 = accounts[5];
    const u3 = accounts[6];

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

    const getUserKey = u => {
        switch (u) {
            case u1:
                return 'u1';
            case u2:
                return 'u2';
            case u3:
                return 'u3';
            case relayer:
                return 'relayer';
        }
    };

    const showLoans = (loans, indentation = 0) => {
        const ind = ' '.repeat(indentation);
        loans.forEach(l => {
            console.log(`${ind}id`, l.id);
            console.log(`${ind}assetID`, l.assetID);
            console.log(`${ind}collateralAccountID`, l.collateralAccountID);
            console.log(`${ind}startAt`, l.startAt);
            console.log(`${ind}expiredAt`, l.expiredAt);
            console.log(`${ind}interestRate`, l.interestRate);
            console.log(`${ind}source`, l.source);
            console.log(`${ind}amount`, l.amount);
        });
    };

    const showCollateralAccountDetails = (account, indentation = 0) => {
        const ind = ' '.repeat(indentation);
        console.log(`${ind}Account:`);
        console.log(`${ind}liquidable`, account.liquidable);
        console.log(`${ind}collateralAssetAmounts`, account.collateralAssetAmounts);
        console.log(`${ind}collateralsTotalUSDlValue`, account.collateralsTotalUSDlValue);
        console.log(`${ind}loanValues`, account.loanValues);
        console.log(`${ind}loansTotalUSDValue`, account.loansTotalUSDValue);
        console.log(`${ind}loans:`);
        showLoans(account.loans, indentation + 2);
    };

    const showStatus = async () => {
        const assetCount = (await hydro.getAllAssetsCount()).toNumber();
        console.log('assetCount:', assetCount);
        // const getBalanceOf = () =>
        const users = [u1, u2, u3, relayer];

        for (let i = 0; i < assetCount; i++) {
            const assetInfo = await hydro.getAssetInfo(i);

            let symbol;
            if (assetInfo.tokenAddress == '0x0000000000000000000000000000000000000000') {
                symbol = 'ETH';
            } else {
                const token = await TestToken.at(assetInfo.tokenAddress);
                symbol = await token.symbol();
            }

            // await hydro.balanceOf(u1);
            for (let j = 0; j < users.length; j++) {
                const balance = await hydro.balanceOf(i, users[j]);
                console.log(`User ${getUserKey(users[j])} ${symbol} balance:`, balance.toString());
            }
        }

        const collateralAccountsCount = (await hydro.getCollateralAccountsCount()).toNumber();

        for (let i = 0; i < collateralAccountsCount; i++) {
            const details = await hydro.getCollateralAccountDetails(i);
            showCollateralAccountDetails(details);
        }
    };

    it('open margin', async () => {
        const [baseToken, quoteToken] = await createAssets([
            {
                symbol: 'ETH',
                name: 'ETH',
                decimals: 18,
                oraclePrice: toWei('500'),
                collateralRate: 15000,
                initBalances: {
                    [u1]: toWei('10'),
                    [u2]: toWei('1')
                }
            },
            {
                symbol: 'USD',
                name: 'USD',
                decimals: 18,
                oraclePrice: toWei('1'),
                collateralRate: 15000,
                initBalances: {
                    [u1]: toWei('1000')
                },
                initPool: {
                    [u1]: toWei('1000')
                }
            }
        ]);

        const openMarginRequest = {
            borrowAssetID: 1, // USD
            collateralAssetID: 0, // ETH
            maxInterestRate: 65535,
            minExpiredAt: 3500000000,
            liquidationRate: 120,
            expiredAt: 3500000000,
            trader: u2,
            minExchangeAmount: toWei('1'),
            borrowAmount: toWei('300'),
            collateralAmount: toWei('1'),
            nonce: '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
        };

        const exchangeParams = {
            takerOrderParam: await buildOrder(
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'market',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 0,
                    asTakerFeeRate: 0,
                    baseTokenAmount: toWei('0'),
                    quoteTokenAmount: toWei('300'),
                    gasTokenAmount: toWei('0')
                },
                baseToken.address,
                quoteToken.address
            ),
            makerOrderParams: [
                await buildOrder(
                    {
                        trader: u1,
                        relayer,
                        version: 2,
                        side: 'sell',
                        type: 'limit',
                        expiredAtSeconds: 3500000000,
                        asMakerFeeRate: 0,
                        asTakerFeeRate: 0,
                        baseTokenAmount: toWei('3'),
                        quoteTokenAmount: toWei('300'),
                        gasTokenAmount: toWei('0')
                    },
                    baseToken.address,
                    quoteToken.address
                )
            ],
            baseTokenFilledAmounts: [toWei('3')],
            orderAddressSet: {
                baseToken: baseToken.address,
                quoteToken: quoteToken.address,
                relayer
            }
        };
        await showStatus();
        const res = await hydro.openMargin(openMarginRequest, exchangeParams, { from: relayer });
        console.log(`        1 Orders, Gas Used:`, res.receipt.gasUsed);
        await showStatus();
    });
});
