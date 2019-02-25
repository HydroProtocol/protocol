const assert = require('assert');
const TestToken = artifacts.require('./helper/TestToken.sol');
const BigNumber = require('bignumber.js');
const { newContract, getWeb3, setHotAmount, getContracts, clone } = require('./utils');
const { generateOrderData, isValidSignature, getOrderHash } = require('../sdk/sdk');
const { fromRpcSig } = require('ethereumjs-util');

const weis = new BigNumber('1000000000000000000');

const toWei = x => {
    return new BigNumber(x).times(weis).toString();
};

const assertEqual = (a, b, allowPrecisionError = false, message = undefined) => {
    a = new BigNumber(a);
    b = new BigNumber(b);

    if (allowPrecisionError) {
        if (a.toString() === b.toString()) {
            assert.equal(a.toString(), b.toString());
        } else {
            assert(
                a
                    .minus(b)
                    .div(b)
                    .lt('0.00000000001'),
                `${message} ${a} ${b}`
            );
        }
    } else {
        assert.equal(a.toString(), b.toString(), message);
    }
};

const infinity = '999999999999999999999999999999999999999999';

contract('Match', async accounts => {
    let exchange, proxy, hot;

    beforeEach(async () => {
        const contracts = await getContracts();
        exchange = contracts.exchange;
        proxy = contracts.proxy;
        hot = contracts.hot;
    });

    const relayer = accounts[9];

    const u1 = accounts[4];
    const u2 = accounts[5];
    const u3 = accounts[6];

    const getOrderSignature = async (order, exchange, baseToken, quoteToken) => {
        const copyedOrder = JSON.parse(JSON.stringify(order));
        copyedOrder.baseToken = baseToken;
        copyedOrder.quoteToken = quoteToken;

        const orderHash = getOrderHash(copyedOrder);
        const newWeb3 = getWeb3();

        // This depends on the client, ganache-cli/testrpc auto prefix the message header to message
        // So we have to set the method ID to 0 even through we use web3.eth.sign
        const signature = fromRpcSig(await newWeb3.eth.sign(orderHash, order.trader));
        signature.config = `0x${signature.v.toString(16)}00` + '0'.repeat(60);
        const isValid = isValidSignature(order.trader, signature, orderHash);

        assert.equal(true, isValid);
        order.signature = signature;
        order.orderHash = orderHash;
    };

    const initToken = async (tokenConfig, users) => {
        const { initBalances } = tokenConfig;

        let token;

        if (tokenConfig.symbol == 'ETH') {
            token = {
                _address: '0x0000000000000000000000000000000000000000',
                symbol: 'ETH'
            };
        } else {
            token = await newContract(
                TestToken,
                tokenConfig.name,
                tokenConfig.symbol,
                tokenConfig.decimals,
                {
                    from: relayer
                }
            );
            token.symbol = tokenConfig.symbol;
        }

        for (let j = 0; j < Object.keys(initBalances).length; j++) {
            const userKey = Object.keys(initBalances)[j];
            const user = users[userKey];
            const amount = initBalances[userKey];

            if (tokenConfig.symbol == 'ETH') {
                await proxy.methods.depositEther().send({ from: user, value: amount });
            } else {
                await token.methods.transfer(user, amount).send({ from: relayer });
                await token.methods.approve(proxy._address, infinity).send({ from: user });
            }
        }

        return token;
    };

    const getTokenUsersBalances = async (token, users, balances) => {
        const symbol = token.symbol;

        for (let i = 0; i < Object.keys(users).length; i++) {
            const userKey = Object.keys(users)[i];
            const user = users[userKey];
            let balance;

            if (symbol == 'ETH') {
                balance = await proxy.methods.balances(user).call();
            } else {
                balance = await token.methods.balanceOf(user).call();
            }

            balances[`${symbol}-${userKey}`] = balance;
        }
    };

    const buildOrder = async (orderParam, exchange, baseTokenAddress, quoteTokenAddress) => {
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

        await getOrderSignature(order, exchange, baseTokenAddress, quoteTokenAddress);

        return order;
    };

    const matchTest = async config => {
        const {
            users,
            baseTokenConfig,
            quoteTokenConfig,
            takerOrderParam,
            makerOrdersParams,
            assertDiffs,
            baseTokenFilledAmounts,
            allowPrecisionError,
            assertFilled
        } = config;

        const balancesBeforeMatch = {};

        const baseToken = await initToken(baseTokenConfig, users);
        const quoteToken = await initToken(quoteTokenConfig, users);

        await getTokenUsersBalances(baseToken, users, balancesBeforeMatch);
        await getTokenUsersBalances(quoteToken, users, balancesBeforeMatch);

        // approve relayer
        if (quoteToken.symbol != 'ETH') {
            await quoteToken.methods.approve(proxy._address, infinity).send({ from: relayer });
        }

        const baseTokenAddress = baseToken._address;
        const quoteTokenAddress = quoteToken._address;

        const takerOrder = await buildOrder(
            takerOrderParam,
            exchange,
            baseTokenAddress,
            quoteTokenAddress
        );
        const makerOrders = [];
        for (let i = 0; i < makerOrdersParams.length; i++) {
            makerOrders.push(
                await buildOrder(
                    makerOrdersParams[i],
                    exchange,
                    baseTokenAddress,
                    quoteTokenAddress
                )
            );
        }

        const res = await exchange.methods
            .matchOrders(takerOrder, makerOrders, baseTokenFilledAmounts, {
                baseToken: baseTokenAddress,
                quoteToken: quoteTokenAddress,
                relayer
            })
            .send({ from: relayer, gas: 10000000, gasLimit: 10000000 });
        console.log(`        ${makerOrders.length} Orders, Gas Used:`, res.gasUsed);

        const balancesAfterMatch = {};

        await getTokenUsersBalances(baseToken, users, balancesAfterMatch);
        await getTokenUsersBalances(quoteToken, users, balancesAfterMatch);
        for (let i = 0; i < Object.keys(assertDiffs).length; i++) {
            const tokenSymbol = Object.keys(assertDiffs)[i];

            for (let j = 0; j < Object.keys(assertDiffs[tokenSymbol]).length; j++) {
                const userKey = Object.keys(assertDiffs[tokenSymbol])[j];
                const expectedDiff = assertDiffs[tokenSymbol][userKey];
                const balanceKey = `${tokenSymbol}-${userKey}`;
                const actualDiff = new BigNumber(balancesAfterMatch[balanceKey]).minus(
                    balancesBeforeMatch[balanceKey]
                );

                assertEqual(
                    actualDiff.toString(),
                    expectedDiff,
                    allowPrecisionError,
                    `${balanceKey}`
                );
            }
        }

        if (assertFilled) {
            const { limitTaker, marketTaker, makers } = assertFilled;

            if (limitTaker && takerOrderParam.type == 'limit') {
                assertEqual(
                    await exchange.methods.filled(takerOrder.orderHash).call(),
                    limitTaker,
                    allowPrecisionError
                );
            }

            if (marketTaker && takerOrderParam.type == 'market') {
                assertEqual(
                    await exchange.methods.filled(takerOrder.orderHash).call(),
                    marketTaker,
                    allowPrecisionError
                );
            }

            if (makers) {
                for (let i = 0; i < makers.length; i++) {
                    assertEqual(
                        await exchange.methods.filled(makerOrders[i].orderHash).call(),
                        makers[i],
                        allowPrecisionError
                    );
                }
            }
        }
    };

    const limitAndMarketTestMatch = async config => {
        await matchTest(config);

        const marketTestConfig = clone(config);
        marketTestConfig.takerOrderParam.type = 'market';

        if (marketTestConfig.takerOrderParam.side === 'sell') {
            marketTestConfig.takerOrderParam.quoteTokenAmount = '0';
        } else {
            marketTestConfig.takerOrderParam.baseTokenAmount = '0';
        }

        await matchTest(marketTestConfig);
    };

    // User1 sell  20  TT (0.18 price)            Taker
    // User2  buy  10  TT (0.19 price)            Maker
    // User3  buy  20  TT (0.18 price) PatialFill Maker
    //
    // Fund changes
    // ╔═════════╤═════╤════════╤═══════════════════════════════════════════════╗
    // ║         │  TT │ ETH    │                                               ║
    // ╠═════════╪═════╪════════╪═══════════════════════════════════════════════╣
    // ║ u1      │ -20 │ 3.415  │ (0.19 * 10 + 0.18 * 10) * 0.95 - 0.1          ║
    // ╟─────────┼─────┼────────┼───────────────────────────────────────────────╢
    // ║ u2      │ 10  │ -2.019 │ -0.19 * 10 * 1.01 - 0.1                       ║
    // ╟─────────┼─────┼────────┼───────────────────────────────────────────────╢
    // ║ u3      │ 10  │ -1.918 │ -0.18 * 10 * 1.01 - 0.1                       ║
    // ╟─────────┼─────┼────────┼───────────────────────────────────────────────╢
    // ║ relayer │ 0   │ 0.522  │ (0.19 * 10 + 0.18 * 10) * (0.05 + 0.01) + 0.3 ║
    // ╚═════════╧═════╧════════╧═══════════════════════════════════════════════╝
    it('taker sell(limit & market), taker full match', async () => {
        const testConfig = {
            baseTokenFilledAmounts: [toWei('10'), toWei('10')],
            users: { u1, u2, u3, relayer },
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u1: toWei(20)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u2: toWei(10),
                    u3: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('20'),
                quoteTokenAmount: toWei('3.6'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteTokenAmount: toWei('1.9'),
                    baseTokenAmount: toWei('10'),
                    gasTokenAmount: toWei('0.1')
                },
                {
                    trader: u3,
                    relayer,
                    version: 1,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteTokenAmount: toWei('3.6'),
                    baseTokenAmount: toWei('20'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('-20'),
                    u2: toWei('10'),
                    u3: toWei('10'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('3.415'),
                    u2: toWei('-2.019'),
                    u3: toWei('-1.918'),
                    relayer: toWei('0.522')
                }
            },
            assertFilled: {
                limitTaker: toWei('20'),
                marketTaker: toWei('20'),
                makers: [toWei('10'), toWei('10')]
            }
        };

        await limitAndMarketTestMatch(testConfig);
    });

    //
    // User1 sell  8424.22  TT (0.03681   price)            Taker
    // User2 buy      1952  TT (0.037821  price)            Maker
    //
    // FUND CHANGES
    // ╔═════════╤══════════╤═══════════════╤═════════════════════════════════╗
    // ║         │  TT      │ WETH          │                                 ║
    // ╠═════════╪══════════╪═══════════════╪═════════════════════════════════╣
    // ║ u1      │  -1952   │  70.0352624   │ (0.037821 * 1952) * 0.95 - 0.1  ║
    // ╟─────────┼──────────┼───────────────┼─────────────────────────────────╢
    // ║ u2      │ 1952     │ -74.66485792  │ -0.037821 * 1952 * 1.01 - 0.1   ║
    // ╟─────────┼──────────┼───────────────┼─────────────────────────────────╢
    // ║ relayer │ 0        │  4.62959552   │ (0.037821 * 1952) * 0.06 + 0.2  ║
    // ╚═════════╧══════════╧═══════════════╧═════════════════════════════════╝
    it('taker sell(limit & market), maker full match', async () => {
        await limitAndMarketTestMatch({
            users: { u1, u2, u3, relayer },
            baseTokenFilledAmounts: [toWei('1952')],
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u1: toWei(10000)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u2: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('8424.22'),
                quoteTokenAmount: toWei('310.0955382'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseTokenAmount: toWei('1952'),
                    quoteTokenAmount: toWei('73.826592'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('-1952'),
                    u2: toWei('1952'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('70.0352624'),
                    u2: toWei('-74.66485792'),
                    relayer: toWei('4.62959552')
                }
            },
            assertFilled: {
                limitTaker: toWei('1952'),
                marketTaker: toWei('1952'),
                makers: [toWei('1952')]
            }
        });
    });

    //
    // User1 buy  8424.22  TT (0.03781   price)            Taker
    // User2 sell    1952  TT (0.036821  price)            Maker
    // User3 sell  314159  TT (0.03780   price) PatialFill Maker
    //
    // FUND CHANGES
    // ╔═════════╤══════════╤═══════════════╤═════════════════════════════════════════════════════╗
    // ║         │  TT      │ WETH          │                                                     ║
    // ╠═════════╪══════════╪═══════════════╪═════════════════════════════════════════════════════╣
    // ║ u1      │ 8424.22  │ -332.4507334  │ -(0.036821 * 1952 + 0.03780 * 6472.22) * 1.05 - 0.1 ║
    // ╟─────────┼──────────┼───────────────┼─────────────────────────────────────────────────────╢
    // ║ u2      │ -1952    │ 71.05584608   │ 0.036821 * 1952 * 0.99 - 0.1                        ║
    // ╟─────────┼──────────┼───────────────┼─────────────────────────────────────────────────────╢
    // ║ u3      │ -6472.22 │ 242.10341684  │ 0.03780 * 6472.22 * 0.99 - 0.1                      ║
    // ╟─────────┼──────────┼───────────────┼─────────────────────────────────────────────────────╢
    // ║ relayer │ 0        │ 19.29147048   │ (0.036821 * 1952 + 0.03780 * 6472.22) * 0.06 + 0.3  ║
    // ╚═════════╧══════════╧═══════════════╧═════════════════════════════════════════════════════╝
    it('taker buy(limit), taker full match', async () => {
        await matchTest({
            baseTokenFilledAmounts: [toWei('1952'), toWei('6472.22')],
            assertFilled: {
                limitTaker: toWei('8424.22'),
                makers: [toWei('1952'), toWei('6472.22')]
            },
            users: { u1, u2, u3, relayer },
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u2: toWei(10000),
                    u3: toWei(10000)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u1: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'buy',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('8424.22'),
                quoteTokenAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseTokenAmount: toWei('1952'),
                    quoteTokenAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                },
                {
                    trader: u3,
                    relayer,
                    version: 1,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseTokenAmount: toWei('314159'),
                    quoteTokenAmount: toWei('11875.2102'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('8424.22'),
                    u2: toWei('-1952'),
                    u3: toWei('-6472.22'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('-332.4507334'),
                    u2: toWei('71.05584608'),
                    u3: toWei('242.10341684'),
                    relayer: toWei('19.29147048')
                }
            }
        });
    });

    // User1 buy  318.5197582 WETH                            Taker
    // User2 sell        1952 TT (0.036821  price)            Maker
    // User3 sell      314159 TT (0.03780   price) PatialFill Maker
    //
    // FUND CHANGES
    // ╔═════════╤══════════════════════════╤════════════════════════╤═════════════════════════════════════════════════════╗
    // ║         │  TT                      │ WETH                   │                                                     ║
    // ╠═════════╪══════════════════════════╪════════════════════════╪═════════════════════════════════════════════════════╣
    // ║ u1      │ 8477.004396825396825396  │ -334.54574611          │ -318.5197582 * 1.05 - 0.1                           ║
    // ╟─────────┼──────────────────────────┼────────────────────────┼─────────────────────────────────────────────────────╢
    // ║ u2      │ -1952                    │ 71.05584608            │ 0.036821 * 1952 * 0.99 - 0.1                        ║
    // ╟─────────┼──────────────────────────┼────────────────────────┼─────────────────────────────────────────────────────╢
    // ║ u3      │ -6525.004396825396825396 │ 244.078714538          │ (6525.004396825396825396 * 0.03780) * 0.99 - 0.1    ║
    // ╟─────────┼──────────────────────────┼────────────────────────┼─────────────────────────────────────────────────────╢
    // ║ relayer │ 0                        │ 19.411185492           │ 318.5197582 * 0.06 + 0.3                            ║
    // ╚═════════╧══════════════════════════╧════════════════════════╧═════════════════════════════════════════════════════╝
    //
    //
    it('taker buy(market), taker full match', async () => {
        await matchTest({
            allowPrecisionError: true,
            baseTokenFilledAmounts: [toWei('1952'), toWei('6525.004396825396825396')],
            assertDiffs: {
                TT: {
                    u1: toWei('8477.004396825396825396'),
                    u2: toWei('-1952'),
                    u3: toWei('-6525.004396825396825396'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('-334.54574611'),
                    u2: toWei('71.05584608'),
                    u3: toWei('244.078714538'),
                    relayer: toWei('19.411185492')
                }
            },
            assertFilled: {
                marketTaker: toWei('318.5197582'),
                makers: [toWei('1952'), toWei('6525.004396825396825396')]
            },
            users: { u1, u2, u3, relayer },
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u2: toWei(10000),
                    u3: toWei(10000)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u1: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'buy',
                type: 'market',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('0'),
                quoteTokenAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseTokenAmount: toWei('1952'),
                    quoteTokenAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                },
                {
                    trader: u3,
                    relayer,
                    version: 1,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseTokenAmount: toWei('314159'),
                    quoteTokenAmount: toWei('11875.2102'),
                    gasTokenAmount: toWei('0.1')
                }
            ]
        });
    });

    //
    // User1 buy  8424.22  TT (0.03781   price)            Taker
    // User2 sell    1952  TT (0.036821  price)            Maker
    //
    // FUND CHANGES
    // ╔═════════╤══════════╤═══════════════╤═════════════════════════════════╗
    // ║         │  TT      │ WETH          │                                 ║
    // ╠═════════╪══════════╪═══════════════╪═════════════════════════════════╣
    // ║ u1      │  1952    │ -75.5683216   │ -(0.036821 * 1952) * 1.05 - 0.1 ║
    // ╟─────────┼──────────┼───────────────┼─────────────────────────────────╢
    // ║ u2      │ -1952    │ 71.05584608   │ 0.036821 * 1952 * 0.99 - 0.1    ║
    // ╟─────────┼──────────┼───────────────┼─────────────────────────────────╢
    // ║ relayer │ 0        │  4.51247552   │ (0.036821 * 1952) * 0.06 + 0.2  ║
    // ╚═════════╧══════════╧═══════════════╧═════════════════════════════════╝
    it('taker buy(limit), maker full match', async () => {
        await matchTest({
            baseTokenFilledAmounts: [toWei('1952')],
            assertFilled: {
                limitTaker: toWei('1952'),
                marketTaker: toWei('71.874592'),
                makers: [toWei('1952')]
            },
            users: { u1, u2, u3, relayer },
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u2: toWei(10000)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u1: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'buy',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('8424.22'),
                quoteTokenAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseTokenAmount: toWei('1952'),
                    quoteTokenAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('1952'),
                    u2: toWei('-1952'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('-75.5683216'),
                    u2: toWei('71.05584608'),
                    relayer: toWei('4.51247552')
                }
            }
        });
    });

    //
    // User1 buy  318.5197582 WETH                  Taker
    // User2 sell        1952 TT (0.036821  price)  Maker
    //
    // FUND CHANGES
    // ╔═════════╤══════════╤═══════════════╤═════════════════════════════════╗
    // ║         │  TT      │ WETH          │                                 ║
    // ╠═════════╪══════════╪═══════════════╪═════════════════════════════════╣
    // ║ u1      │  1952    │ -75.5683216   │ -(0.036821 * 1952) * 1.05 - 0.1 ║
    // ╟─────────┼──────────┼───────────────┼─────────────────────────────────╢
    // ║ u2      │ -1952    │ 71.05584608   │ 0.036821 * 1952 * 0.99 - 0.1    ║
    // ╟─────────┼──────────┼───────────────┼─────────────────────────────────╢
    // ║ relayer │ 0        │  4.51247552   │ (0.036821 * 1952) * 0.06 + 0.2  ║
    // ╚═════════╧══════════╧═══════════════╧═════════════════════════════════╝
    it('taker buy(market), maker full match', async () => {
        await matchTest({
            baseTokenFilledAmounts: [toWei('1952')],
            assertFilled: {
                marketTaker: toWei('71.874592'),
                makers: [toWei('1952')]
            },
            users: { u1, u2, u3, relayer },
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u2: toWei(10000)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u1: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'buy',
                type: 'market',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('0'),
                quoteTokenAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseTokenAmount: toWei('1952'),
                    quoteTokenAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('1952'),
                    u2: toWei('-1952'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('-75.5683216'),
                    u2: toWei('71.05584608'),
                    relayer: toWei('4.51247552')
                }
            }
        });
    });

    //
    // User1 buy  8424.22  TT (0.03781   price) Taker
    // User2 sell    1952  TT (0.036821  price) Maker
    // User1(Taker) has 10000 HOT
    //
    // FUND CHANGES
    // ╔═════════╤══════════╤═══════════════╤═══════════════════════════════════════════════╗
    // ║         │  TT      │ WETH          │                                               ║
    // ╠═════════╪══════════╪═══════════════╪═══════════════════════════════════════════════╣
    // ║ u1      │  1952    │ -75.20894864  │ -(0.036821 * 1952) * (1 + 0.05 * 0.9) - 0.1   ║
    // ╟─────────┼──────────┼───────────────┼───────────────────────────────────────────────╢
    // ║ u2      │ -1952    │ 71.05584608   │ 0.036821 * 1952 * 0.99 - 0.1                  ║
    // ╟─────────┼──────────┼───────────────┼───────────────────────────────────────────────╢
    // ║ relayer │ 0        │  4.51247552   │ (0.036821 * 1952) * (0.05 * 0.9 + 0.01) + 0.2 ║
    // ╚═════════╧══════════╧═══════════════╧═══════════════════════════════════════════════╝
    it('HOT discount', async () => {
        await setHotAmount(hot, u1, toWei(10000));
        await matchTest({
            baseTokenFilledAmounts: [toWei('1952')],
            users: { u1, u2, u3, relayer },
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u2: toWei(10000)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u1: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'buy',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('8424.22'),
                quoteTokenAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseTokenAmount: toWei('1952'),
                    quoteTokenAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('1952'),
                    u2: toWei('-1952'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('-75.20894864'),
                    u2: toWei('71.05584608'),
                    relayer: toWei('4.15310256')
                }
            }
        });
    });

    //
    // User1 sell   102  TT Taker Market Order
    // User2  buy   312  TT (0.0008273 price) Maker
    // User2  has 10000 HOT
    //
    // FUND CHANGES
    // ╔═════════╤══════════╤═══════════════╤═══════════════════════════════════════════════════╗
    // ║         │  TT      │ WETH          │                                                   ║
    // ╠═════════╪══════════╪═══════════════╪═══════════════════════════════════════════════════╣
    // ║ u1      │  -102    │   0.08015537  │ (0.0008273 * 102) * (1 - 0.05) - 0.00001          ║
    // ╟─────────┼──────────┼───────────────┼───────────────────────────────────────────────────╢
    // ║ u2      │   102    │ -0.0851540614 │ -0.0008273 * 102 * (1 + 0.01 * 0.9) - 0.00001     ║
    // ╟─────────┼──────────┼───────────────┼───────────────────────────────────────────────────╢
    // ║ relayer │    0     │ 0.0049986914  │ (0.0008273 * 102) * (0.01 * 0.9 + 0.05) + 0.00002 ║
    // ╚═════════╧══════════╧═══════════════╧═══════════════════════════════════════════════════╝
    it('eth, taker market order sell, taker full match, maker fee discount', async () => {
        await setHotAmount(hot, u2, toWei(10000));
        await matchTest({
            baseTokenFilledAmounts: [toWei('102')],
            users: { u1, u2, relayer },
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u1: toWei(10000)
                }
            },
            quoteTokenConfig: {
                name: 'Ethereum',
                symbol: 'ETH',
                decimals: 18,
                initBalances: {
                    u2: toWei('0.5')
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'sell',
                type: 'market',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('102'),
                quoteTokenAmount: toWei('0'),
                gasTokenAmount: toWei('0.00001')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseTokenAmount: toWei('312'),
                    quoteTokenAmount: toWei('0.2581176'),
                    gasTokenAmount: toWei('0.00001')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('-102'),
                    u2: toWei('102'),
                    relayer: toWei('0')
                },
                ETH: {
                    u1: toWei('0.08015537'),
                    u2: toWei('-0.0851540614'),
                    relayer: toWei('0.0049986914')
                }
            }
        });
    });

    //
    // User1 buy  8424.22  TT (0.03781   price) Taker
    // User2 sell    1952  TT (0.036821  price) Maker Rebate 0.5%
    //
    // FUND CHANGES
    // ╔═════════╤══════════╤═══════════════╤═════════════════════════════════╗
    // ║         │  TT      │ WETH          │                                 ║
    // ╠═════════╪══════════╪═══════════════╪═════════════════════════════════╣
    // ║ u1      │  1952    │ -75.5683216   │ -(0.036821 * 1952) * 1.05 - 0.1 ║
    // ╟─────────┼──────────┼───────────────┼─────────────────────────────────╢
    // ║ u2      │ -1952    │ 71.41521904   │ 0.036821 * 1952 * 0.995 - 0.1   ║
    // ╟─────────┼──────────┼───────────────┼─────────────────────────────────╢
    // ║ relayer │ 0        │  4.15310256   │ (0.036821 * 1952) * 0.055 + 0.2 ║
    // ╚═════════╧══════════╧═══════════════╧═════════════════════════════════╝
    it('Maker Rebate Rate < Maker fee Rate', async () => {
        await limitAndMarketTestMatch({
            users: { u1, u2, u3, relayer },
            baseTokenFilledAmounts: [toWei('1952')],
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u2: toWei(10000)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u1: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'buy',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('8424.22'),
                quoteTokenAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    makerRebateRate: 500,
                    baseTokenAmount: toWei('1952'),
                    quoteTokenAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('1952'),
                    u2: toWei('-1952'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('-75.5683216'),
                    u2: toWei('71.41521904'),
                    relayer: toWei('4.15310256')
                }
            }
        });
    });

    //
    // User1 buy  8424.22  TT (0.03781   price)            Taker
    // User2 sell    1952  TT (0.036821  price)            Maker rebate 1%
    // User3 sell  314159  TT (0.03780   price) PatialFill Maker
    //
    // FUND CHANGES
    // ╔═════════╤══════════╤═══════════════╤════════════════════════════════════════════════════════════╗
    // ║         │  TT      │ WETH          │                                                            ║
    // ╠═════════╪══════════╪═══════════════╪════════════════════════════════════════════════════════════╣
    // ║ u1      │ 8424.22  │ -332.4507334  │ -(0.036821 * 1952 + 0.03780 * 6472.22) * 1.05 - 0.1        ║
    // ╟─────────┼──────────┼───────────────┼────────────────────────────────────────────────────────────╢
    // ║ u2      │ -1952    │ 71.774592     │ 0.036821 * 1952 - 0.1                                      ║
    // ╟─────────┼──────────┼───────────────┼────────────────────────────────────────────────────────────╢
    // ║ u3      │ -6472.22 │ 242.10341684  │ 0.03780 * 6472.22 * 0.99 - 0.1                             ║
    // ╟─────────┼──────────┼───────────────┼────────────────────────────────────────────────────────────╢
    // ║ relayer │ 0        │ 18.57272456   │ 0.036821 * 1952 * 0.05 + (0.03780 * 6472.22) * 0.06 + 0.3  ║
    // ╚═════════╧══════════╧═══════════════╧════════════════════════════════════════════════════════════╝
    it('Maker Rebate Rate == Maker Fee Rate', async () => {
        await limitAndMarketTestMatch({
            users: { u1, u2, u3, relayer },
            baseTokenFilledAmounts: [toWei('1952'), toWei('6472.22')],
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u2: toWei(10000),
                    u3: toWei(10000)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u1: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'buy',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('8424.22'),
                quoteTokenAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    makerRebateRate: 1000,
                    baseTokenAmount: toWei('1952'),
                    quoteTokenAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                },
                {
                    trader: u3,
                    relayer,
                    version: 1,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseTokenAmount: toWei('6472.22'),
                    quoteTokenAmount: toWei('244.649916'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('8424.22'),
                    u2: toWei('-1952'),
                    u3: toWei('-6472.22'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('-332.4507334'),
                    u2: toWei('71.774592'),
                    u3: toWei('242.10341684'),
                    relayer: toWei('18.57272456')
                }
            }
        });
    });

    // User1 sell  20  TT (0.18 price)            Taker
    // User2  buy  10  TT (0.19 price)            Maker  Rebate 2%
    // User3  buy  20  TT (0.18 price) PatialFill Maker
    //
    // Fund changes
    // ╔═════════╤═════╤════════╤═══════════════════════════════════════════════╗
    // ║         │  TT │ ETH    │                                               ║
    // ╠═════════╪═════╪════════╪═══════════════════════════════════════════════╣
    // ║ u1      │ -20 │ 3.415  │ (0.19 * 10 + 0.18 * 10) * 0.95 - 0.1          ║
    // ╟─────────┼─────┼────────┼───────────────────────────────────────────────╢
    // ║ u2      │ 10  │ -1.981 │ -0.19 * 10 * (1 + 0.01 - 0.02) - 0.1          ║
    // ╟─────────┼─────┼────────┼───────────────────────────────────────────────╢
    // ║ u3      │ 10  │ -1.918 │ -0.18 * 10 * 1.01 - 0.1                       ║
    // ╟─────────┼─────┼────────┼───────────────────────────────────────────────╢
    // ║ relayer │ 0   │ 0.484  │ 0.18 * 10 * 0.06 + 0.19 * 10 * 0.04 + 0.3     ║
    // ╚═════════╧═════╧════════╧═══════════════════════════════════════════════╝
    it('Maker Rebate Rate > Maker Fee Rate & rebate < taker fee', async () => {
        const testConfig = {
            baseTokenFilledAmounts: [toWei('10'), toWei('10')],
            users: { u1, u2, u3, relayer },
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u1: toWei(20)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u2: toWei(10),
                    u3: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('20'),
                quoteTokenAmount: toWei('3.6'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 2000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteTokenAmount: toWei('1.9'),
                    baseTokenAmount: toWei('10'),
                    gasTokenAmount: toWei('0.1')
                },
                {
                    trader: u3,
                    relayer,
                    version: 1,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteTokenAmount: toWei('3.6'),
                    baseTokenAmount: toWei('20'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('-20'),
                    u2: toWei('10'),
                    u3: toWei('10'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('3.415'),
                    u2: toWei('-1.981'),
                    u3: toWei('-1.918'),
                    relayer: toWei('0.484')
                }
            }
        };

        await limitAndMarketTestMatch(testConfig);
    });

    // User1 sell  20  TT (0.18 price)            Taker
    // User2  buy  10  TT (0.19 price)            Maker  Rebate 10%
    // User3  buy  20  TT (0.18 price) PatialFill Maker
    //
    // Fund changes
    // ╔═════════╤═════╤════════╤═══════════════════════════════════════════════╗
    // ║         │  TT │ ETH    │                                               ║
    // ╠═════════╪═════╪════════╪═══════════════════════════════════════════════╣
    // ║ u1      │ -20 │ 3.415  │ (0.19 * 10 + 0.18 * 10) * 0.95 - 0.1          ║
    // ╟─────────┼─────┼────────┼───────────────────────────────────────────────╢
    // ║ u2      │ 10  │ -1.905 │ -0.19 * 10 * 0.95 - 0.1                       ║
    // ╟─────────┼─────┼────────┼───────────────────────────────────────────────╢
    // ║ u3      │ 10  │ -1.918 │ -0.18 * 10 * 1.01 - 0.1                       ║
    // ╟─────────┼─────┼────────┼───────────────────────────────────────────────╢
    // ║ relayer │ 0   │ 0.408  │ 0.18 * 10 * 0.06 + 0.3                        ║
    // ╚═════════╧═════╧════════╧═══════════════════════════════════════════════╝
    it('Maker Rebate Rate > Maker Fee Rate & rebate > taker fee', async () => {
        const testConfig = {
            baseTokenFilledAmounts: [toWei('10'), toWei('10')],
            users: { u1, u2, u3, relayer },
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u1: toWei(20)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u2: toWei(10),
                    u3: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('20'),
                quoteTokenAmount: toWei('3.6'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 6553,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteTokenAmount: toWei('1.9'),
                    baseTokenAmount: toWei('10'),
                    gasTokenAmount: toWei('0.1')
                },
                {
                    trader: u3,
                    relayer,
                    version: 1,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteTokenAmount: toWei('3.6'),
                    baseTokenAmount: toWei('20'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('-20'),
                    u2: toWei('10'),
                    u3: toWei('10'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('3.415'),
                    u2: toWei('-1.905'),
                    u3: toWei('-1.918'),
                    relayer: toWei('0.408')
                }
            }
        };

        await limitAndMarketTestMatch(testConfig);
    });

    // invalid taker order
    it('Invalid taker order will revert', async () => {
        const testConfig = {
            baseTokenFilledAmounts: [toWei('1')],
            users: { u1, u2, u3, relayer },
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u1: toWei(20)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u2: toWei(10),
                    u3: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('0'),
                quoteTokenAmount: toWei('0'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 6553,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteTokenAmount: toWei('1'),
                    baseTokenAmount: toWei('1'),
                    gasTokenAmount: toWei('0.1')
                }
            ]
        };

        try {
            await limitAndMarketTestMatch(testConfig);
            assert(false, 'Should never get here');
        } catch (e) {
            assert.ok(e.message.match(/revert/));
        }
    });

    // invalid maker order
    it('Invalid taker order will revert', async () => {
        const testConfig = {
            baseTokenFilledAmounts: [toWei('1')],
            users: { u1, u2, u3, relayer },
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u1: toWei(20)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u2: toWei(10),
                    u3: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseTokenAmount: toWei('1'),
                quoteTokenAmount: toWei('1'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 6553,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteTokenAmount: toWei('0'),
                    baseTokenAmount: toWei('0'),
                    gasTokenAmount: toWei('0.1')
                }
            ]
        };

        try {
            await limitAndMarketTestMatch(testConfig);
            assert(false, 'Should never get here');
        } catch (e) {
            assert.ok(e.message.match(/revert/));
        }
    });

    it('match without fees', async () => {
        const testConfig = {
            users: { u1, u2, relayer },
            baseTokenFilledAmounts: [toWei('1')],
            baseTokenConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    u1: toWei(20)
                }
            },
            quoteTokenConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    u2: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 1,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 0,
                asTakerFeeRate: 0,
                baseTokenAmount: toWei('1'),
                quoteTokenAmount: toWei('1'),
                gasTokenAmount: toWei('0')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 1,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 0,
                    asMakerFeeRate: 0,
                    asTakerFeeRate: 0,
                    quoteTokenAmount: toWei('1'),
                    baseTokenAmount: toWei('1'),
                    gasTokenAmount: toWei('0')
                }
            ],
            assertDiffs: {
                TT: {
                    u1: toWei('-1'),
                    u2: toWei('1'),
                    relayer: toWei('0')
                },
                WETH: {
                    u1: toWei('1'),
                    u2: toWei('-1'),
                    relayer: toWei('0')
                }
            }
        };

        await limitAndMarketTestMatch(testConfig);
    });
});
