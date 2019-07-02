require('../utils/hooks');
const assert = require('assert');
const Hydro = artifacts.require('./Hydro.sol');
const BigNumber = require('bignumber.js');
const { setHotAmount, pp, clone, toWei, wei, getUserKey, logGas } = require('../utils');
const { buildOrder } = require('../utils/order');
const { revert, snapshot } = require('../utils/evm');
const { transfer, supply, borrow } = require('../../sdk/sdk');
const { createAsset, newMarket } = require('../utils/assets');

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

contract('Match', async accounts => {
    let hydro;

    before(async () => {
        hydro = await Hydro.deployed();
    });

    const relayer = accounts[9];

    const u1 = accounts[4];
    const u2 = accounts[5];
    const u3 = accounts[6];

    const users = [relayer, u1, u2, u3];

    const getUsersAssetsBalances = async (tokens, balancePaths) => {
        const balances = {};
        for (let i = 0; i < tokens.length; i++) {
            const token = tokens[i];
            const symbol = token.symbol;

            for (let j = 0; j < Object.keys(users).length; j++) {
                const user = users[j];
                let balance;

                if (balancePaths && balancePaths[user] && balancePaths[user].category == 1) {
                    balance = await hydro.marketBalanceOf(
                        balancePaths[user].marketID,
                        token.address,
                        user
                    );
                } else {
                    balance = await hydro.balanceOf(token.address, user);
                }

                balances[`${symbol}-${user}`] = balance;
            }
        }
        return balances;
    };

    const tryToDepositToMarketBalances = async (
        baseAssetConfig,
        baseAsset,
        quoteAssetConfig,
        quoteAsset,
        userBalancePaths
    ) => {
        const users = Object.keys(userBalancePaths);
        for (let j = 0; j < users.length; j++) {
            const user = users[j];
            const path = userBalancePaths[user];

            if (path.category == 0) {
                continue;
            }

            if (
                baseAssetConfig &&
                baseAssetConfig.initBalances &&
                baseAssetConfig.initBalances[user]
            ) {
                await transfer(
                    baseAsset.address,
                    {
                        category: 0,
                        marketID: 0,
                        user
                    },
                    path,
                    baseAssetConfig.initBalances[user],
                    { from: user }
                );
            }

            if (
                quoteAssetConfig &&
                quoteAssetConfig.initBalances &&
                quoteAssetConfig.initBalances[user]
            ) {
                await transfer(
                    quoteAsset.address,
                    {
                        category: 0,
                        marketID: 0,
                        user
                    },
                    path,
                    quoteAssetConfig.initBalances[user],
                    { from: user }
                );
            }
        }
    };

    const matchTest = async config => {
        const {
            userBalancePaths,
            baseAssetConfig,
            quoteAssetConfig,
            takerOrderParam,
            makerOrdersParams,
            assertDiffs,
            baseAssetFilledAmounts,
            beforeMatch,
            afterMatch,
            allowPrecisionError,
            assertFilled
        } = config;

        const baseAsset = await createAsset(baseAssetConfig);
        const quoteAsset = await createAsset(quoteAssetConfig);

        if (userBalancePaths) {
            await newMarket({ assets: [baseAsset, quoteAsset] });

            // if the user has a special balances path, try to deposit all initBalances into market balances
            await tryToDepositToMarketBalances(
                baseAssetConfig,
                baseAsset,
                quoteAssetConfig,
                quoteAsset,
                userBalancePaths
            );
        }

        const baseAssetAddress = baseAsset.address;
        const quoteAssetAddress = quoteAsset.address;
        const orderAddressSet = {
            baseAsset: baseAssetAddress,
            quoteAsset: quoteAssetAddress,
            relayer
        };

        const takerOrder = await buildOrder(takerOrderParam, baseAssetAddress, quoteAssetAddress);

        const makerOrders = [];

        for (let i = 0; i < makerOrdersParams.length; i++) {
            makerOrders.push(
                await buildOrder(makerOrdersParams[i], baseAssetAddress, quoteAssetAddress)
            );
        }

        if (beforeMatch) {
            await beforeMatch({
                takerOrder,
                makerOrders,
                baseAsset,
                quoteAsset,
                baseAssetFilledAmounts,
                orderAddressSet
            });
        }

        const balancesBeforeMatch = await getUsersAssetsBalances(
            [baseAsset, quoteAsset],
            userBalancePaths
        );

        const res = await hydro.matchOrders(
            {
                takerOrderParam: takerOrder,
                makerOrderParams: makerOrders,
                baseAssetFilledAmounts: baseAssetFilledAmounts,
                orderAddressSet
            },
            { from: relayer }
        );

        if (afterMatch) {
            await afterMatch({
                takerOrder,
                makerOrders,
                baseAssetFilledAmounts,
                orderAddressSet
            });
        }

        logGas(res, `hydro.matchOrders (${makerOrders.length} Orders)`);

        const balancesAfterMatch = await getUsersAssetsBalances(
            [baseAsset, quoteAsset],
            userBalancePaths
        );
        for (let i = 0; i < Object.keys(assertDiffs).length; i++) {
            const tokenSymbol = Object.keys(assertDiffs)[i];

            for (let j = 0; j < Object.keys(assertDiffs[tokenSymbol]).length; j++) {
                const user = Object.keys(assertDiffs[tokenSymbol])[j];
                const expectedDiff = assertDiffs[tokenSymbol][user];
                const balanceKey = `${tokenSymbol}-${user}`;
                const actualDiff = new BigNumber(balancesAfterMatch[balanceKey]).minus(
                    balancesBeforeMatch[balanceKey]
                );

                assertEqual(
                    actualDiff.toString(),
                    expectedDiff,
                    allowPrecisionError,
                    `${tokenSymbol}-${await getUserKey(user)}`
                );
            }
        }

        if (assertFilled) {
            const { limitTaker, marketTaker, makers } = assertFilled;

            if (limitTaker && takerOrderParam.type == 'limit') {
                assertEqual(
                    await hydro.getOrderFilledAmount(takerOrder.orderHash),
                    limitTaker,
                    allowPrecisionError
                );
            }

            if (marketTaker && takerOrderParam.type == 'market') {
                assertEqual(
                    await hydro.getOrderFilledAmount(takerOrder.orderHash),
                    marketTaker,
                    allowPrecisionError
                );
            }

            if (makers) {
                for (let i = 0; i < makers.length; i++) {
                    assertEqual(
                        await hydro.getOrderFilledAmount(makerOrders[i].orderHash),
                        makers[i],
                        allowPrecisionError
                    );
                }
            }
        }
    };

    const limitAndMarketTestMatch = async config => {
        const snapshotID = await snapshot();
        await matchTest(config);
        await revert(snapshotID);

        const marketTestConfig = clone(config);
        marketTestConfig.takerOrderParam.type = 'market';

        if (marketTestConfig.takerOrderParam.side === 'sell') {
            marketTestConfig.takerOrderParam.quoteAssetAmount = '0';
        } else {
            marketTestConfig.takerOrderParam.baseAssetAmount = '0';
        }

        if (config.beforeMatch) {
            marketTestConfig.beforeMatch = config.beforeMatch;
        }

        if (config.afterMatch) {
            marketTestConfig.afterMatch = config.afterMatch;
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
            baseAssetFilledAmounts: [toWei('10'), toWei('10')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(20)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10),
                    [u3]: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('20'),
                quoteAssetAmount: toWei('3.6'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteAssetAmount: toWei('1.9'),
                    baseAssetAmount: toWei('10'),
                    gasTokenAmount: toWei('0.1')
                },
                {
                    trader: u3,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteAssetAmount: toWei('3.6'),
                    baseAssetAmount: toWei('20'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('-20'),
                    [u2]: toWei('10'),
                    [u3]: toWei('10'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('3.415'),
                    [u2]: toWei('-2.019'),
                    [u3]: toWei('-1.918'),
                    [relayer]: toWei('0.522')
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
            baseAssetFilledAmounts: [toWei('1952')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(10000)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('8424.22'),
                quoteAssetAmount: toWei('310.0955382'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseAssetAmount: toWei('1952'),
                    quoteAssetAmount: toWei('73.826592'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('-1952'),
                    [u2]: toWei('1952'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('70.0352624'),
                    [u2]: toWei('-74.66485792'),
                    [relayer]: toWei('4.62959552')
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
            baseAssetFilledAmounts: [toWei('1952'), toWei('6472.22')],
            assertFilled: {
                limitTaker: toWei('8424.22'),
                makers: [toWei('1952'), toWei('6472.22')]
            },
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10000),
                    [u3]: toWei(10000)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'buy',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('8424.22'),
                quoteAssetAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseAssetAmount: toWei('1952'),
                    quoteAssetAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                },
                {
                    trader: u3,
                    relayer,
                    version: 2,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseAssetAmount: toWei('314159'),
                    quoteAssetAmount: toWei('11875.2102'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('8424.22'),
                    [u2]: toWei('-1952'),
                    [u3]: toWei('-6472.22'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('-332.4507334'),
                    [u2]: toWei('71.05584608'),
                    [u3]: toWei('242.10341684'),
                    [relayer]: toWei('19.29147048')
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
            baseAssetFilledAmounts: [toWei('1952'), toWei('6525.004396825396825396')],
            assertDiffs: {
                TT: {
                    [u1]: toWei('8477.004396825396825396'),
                    [u2]: toWei('-1952'),
                    [u3]: toWei('-6525.004396825396825396'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('-334.54574611'),
                    [u2]: toWei('71.05584608'),
                    [u3]: toWei('244.078714538'),
                    [relayer]: toWei('19.411185492')
                }
            },
            assertFilled: {
                marketTaker: toWei('318.5197582'),
                makers: [toWei('1952'), toWei('6525.004396825396825396')]
            },
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10000),
                    [u3]: toWei(10000)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'buy',
                type: 'market',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('0'),
                quoteAssetAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseAssetAmount: toWei('1952'),
                    quoteAssetAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                },
                {
                    trader: u3,
                    relayer,
                    version: 2,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseAssetAmount: toWei('314159'),
                    quoteAssetAmount: toWei('11875.2102'),
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
            baseAssetFilledAmounts: [toWei('1952')],
            assertFilled: {
                limitTaker: toWei('1952'),
                marketTaker: toWei('71.874592'),
                makers: [toWei('1952')]
            },
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10000)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'buy',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('8424.22'),
                quoteAssetAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseAssetAmount: toWei('1952'),
                    quoteAssetAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('1952'),
                    [u2]: toWei('-1952'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('-75.5683216'),
                    [u2]: toWei('71.05584608'),
                    [relayer]: toWei('4.51247552')
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
            baseAssetFilledAmounts: [toWei('1952')],
            assertFilled: {
                marketTaker: toWei('71.874592'),
                makers: [toWei('1952')]
            },
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10000)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'buy',
                type: 'market',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('0'),
                quoteAssetAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseAssetAmount: toWei('1952'),
                    quoteAssetAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('1952'),
                    [u2]: toWei('-1952'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('-75.5683216'),
                    [u2]: toWei('71.05584608'),
                    [relayer]: toWei('4.51247552')
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
        await setHotAmount(u1, toWei(10000));
        await matchTest({
            baseAssetFilledAmounts: [toWei('1952')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10000)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'buy',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('8424.22'),
                quoteAssetAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseAssetAmount: toWei('1952'),
                    quoteAssetAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('1952'),
                    [u2]: toWei('-1952'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('-75.20894864'),
                    [u2]: toWei('71.05584608'),
                    [relayer]: toWei('4.15310256')
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
        await setHotAmount(u2, toWei(10000));
        await matchTest({
            baseAssetFilledAmounts: [toWei('102')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(10000)
                }
            },
            quoteAssetConfig: {
                name: 'Ethereum',
                symbol: 'ETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei('0.5')
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'market',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('102'),
                quoteAssetAmount: toWei('0'),
                gasTokenAmount: toWei('0.00001')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    baseAssetAmount: toWei('312'),
                    quoteAssetAmount: toWei('0.2581176'),
                    gasTokenAmount: toWei('0.00001')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('-102'),
                    [u2]: toWei('102'),
                    [relayer]: toWei('0')
                },
                ETH: {
                    [u1]: toWei('0.08015537'),
                    [u2]: toWei('-0.0851540614'),
                    [relayer]: toWei('0.0049986914')
                }
            }
        });
    });

    //
    // User1 buy  8424.22  TT (0.03781   price) Taker
    // User2 sell    1952  TT (0.036821  price) Maker Rebate 50%
    //
    // FUND CHANGES
    // ╔═════════╤══════════╤═══════════════╤════════════════════════════════════════════╗
    // ║         │  TT      │ WETH          │                                            ║
    // ╠═════════╪══════════╪═══════════════╪════════════════════════════════════════════╣
    // ║ u1      │  1952    │ -75.5683216   │ -(0.036821 * 1952) * 1.05 - 0.1            ║
    // ╟─────────┼──────────┼───────────────┼────────────────────────────────────────────╢
    // ║ u2      │ -1952    │ 73.5714568    │ (0.036821 * 1952) * (1 + 0.05 * 0.5) - 0.1 ║
    // ╟─────────┼──────────┼───────────────┼────────────────────────────────────────────╢
    // ║ relayer │ 0        │  1.9968648    │ (0.036821 * 1952) * (0.05 * 0.5) + 0.2     ║
    // ╚═════════╧══════════╧═══════════════╧════════════════════════════════════════════╝
    it('Maker Rebate 50%', async () => {
        await limitAndMarketTestMatch({
            baseAssetFilledAmounts: [toWei('1952')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10000)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(5000)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'buy',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('8424.22'),
                quoteAssetAmount: toWei('318.5197582'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000, // It will have no effect
                    asTakerFeeRate: 5000,
                    makerRebateRate: 50,
                    baseAssetAmount: toWei('1952'),
                    quoteAssetAmount: toWei('71.874592'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('1952'),
                    [u2]: toWei('-1952'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('-75.5683216'),
                    [u2]: toWei('73.5714568'),
                    [relayer]: toWei('1.9968648')
                }
            }
        });
    });

    // User1 sell  20  TT (0.18 price)            Taker
    // User2  buy  10  TT (0.19 price)            Maker  Rebate 100%
    // User3  buy  20  TT (0.18 price) PatialFill Maker
    //
    // Fund changes
    // ╔═════════╤═════╤═════════╤═══════════════════════════════════════════════╗
    // ║         │  TT │ ETH     │                                               ║
    // ╠═════════╪═════╪═════════╪═══════════════════════════════════════════════╣
    // ║ u1      │ -20 │ 3.415   │ (0.19 * 10 + 0.18 * 10) * 0.95 - 0.1          ║
    // ╟─────────┼─────┼─────────┼───────────────────────────────────────────────╢
    // ║ u2      │ 10  │ -1.905  │ -0.19 * 10 * (1 - 0.05) - 0.1                 ║
    // ╟─────────┼─────┼─────────┼───────────────────────────────────────────────╢
    // ║ u3      │ 10  │ -1.918  │ -0.18 * 10 * 1.01 - 0.1                       ║
    // ╟─────────┼─────┼─────────┼───────────────────────────────────────────────╢
    // ║ relayer │ 0   │ 0.408   │ 0.18 * 10 * 0.06 + 0.3                        ║
    // ╚═════════╧═════╧═════════╧═══════════════════════════════════════════════╝
    it('Maker Rebate Rate is 100%', async () => {
        const testConfig = {
            baseAssetFilledAmounts: [toWei('10'), toWei('10')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(20)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10),
                    [u3]: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('20'),
                quoteAssetAmount: toWei('3.6'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 100,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteAssetAmount: toWei('1.9'),
                    baseAssetAmount: toWei('10'),
                    gasTokenAmount: toWei('0.1')
                },
                {
                    trader: u3,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteAssetAmount: toWei('3.6'),
                    baseAssetAmount: toWei('20'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('-20'),
                    [u2]: toWei('10'),
                    [u3]: toWei('10'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('3.415'),
                    [u2]: toWei('-1.905'),
                    [u3]: toWei('-1.918'),
                    [relayer]: toWei('0.408')
                }
            }
        };

        await limitAndMarketTestMatch(testConfig);
    });

    // User1 sell  20  TT (0.18 price)            Taker
    // User2  buy  10  TT (0.19 price)            Maker  Rebate 200%
    // User3  buy  20  TT (0.18 price) PatialFill Maker
    //
    // Fund changes
    // ╔═════════╤═════╤═════════╤═══════════════════════════════════════════════╗
    // ║         │  TT │ ETH     │                                               ║
    // ╠═════════╪═════╪═════════╪═══════════════════════════════════════════════╣
    // ║ u1      │ -20 │ 3.415   │ (0.19 * 10 + 0.18 * 10) * 0.95 - 0.1          ║
    // ╟─────────┼─────┼─────────┼───────────────────────────────────────────────╢
    // ║ u2      │ 10  │ -1.905  │ -0.19 * 10 * (1 - 0.05) - 0.1                 ║
    // ╟─────────┼─────┼─────────┼───────────────────────────────────────────────╢
    // ║ u3      │ 10  │ -1.918  │ -0.18 * 10 * 1.01 - 0.1                       ║
    // ╟─────────┼─────┼─────────┼───────────────────────────────────────────────╢
    // ║ relayer │ 0   │ 0.408   │ 0.18 * 10 * 0.06 + 0.3                        ║
    // ╚═════════╧═════╧═════════╧═══════════════════════════════════════════════╝
    it('Maker Rebate Rate large than 100%(will be calculated as 100%)', async () => {
        const testConfig = {
            baseAssetFilledAmounts: [toWei('10'), toWei('10')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(20)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10),
                    [u3]: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('20'),
                quoteAssetAmount: toWei('3.6'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 200, // should be used as 100% in contract
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteAssetAmount: toWei('1.9'),
                    baseAssetAmount: toWei('10'),
                    gasTokenAmount: toWei('0.1')
                },
                {
                    trader: u3,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteAssetAmount: toWei('3.6'),
                    baseAssetAmount: toWei('20'),
                    gasTokenAmount: toWei('0.1')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('-20'),
                    [u2]: toWei('10'),
                    [u3]: toWei('10'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('3.415'),
                    [u2]: toWei('-1.905'),
                    [u3]: toWei('-1.918'),
                    [relayer]: toWei('0.408')
                }
            }
        };

        await limitAndMarketTestMatch(testConfig);
    });

    // invalid taker order
    it('Invalid taker order will revert', async () => {
        const testConfig = {
            baseAssetFilledAmounts: [toWei('1')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(20)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10),
                    [u3]: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('0'),
                quoteAssetAmount: toWei('0'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 6553,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteAssetAmount: toWei('1'),
                    baseAssetAmount: toWei('1'),
                    gasTokenAmount: toWei('0.1')
                }
            ]
        };

        await assert.rejects(limitAndMarketTestMatch(testConfig), /revert/);
    });

    // invalid maker order
    it('Invalid taker order will revert', async () => {
        const testConfig = {
            baseAssetFilledAmounts: [toWei('1')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(20)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10),
                    [u3]: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 1000,
                asTakerFeeRate: 5000,
                baseAssetAmount: toWei('1'),
                quoteAssetAmount: toWei('1'),
                gasTokenAmount: toWei('0.1')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 6553,
                    asMakerFeeRate: 1000,
                    asTakerFeeRate: 5000,
                    quoteAssetAmount: toWei('0'),
                    baseAssetAmount: toWei('0'),
                    gasTokenAmount: toWei('0.1')
                }
            ]
        };

        await assert.rejects(limitAndMarketTestMatch(testConfig), /revert/);
    });

    it('match without fees', async () => {
        const testConfig = {
            baseAssetFilledAmounts: [toWei('1')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(20)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 0,
                asTakerFeeRate: 0,
                baseAssetAmount: toWei('1'),
                quoteAssetAmount: toWei('1'),
                gasTokenAmount: toWei('0')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 0,
                    asMakerFeeRate: 0,
                    asTakerFeeRate: 0,
                    quoteAssetAmount: toWei('1'),
                    baseAssetAmount: toWei('1'),
                    gasTokenAmount: toWei('0')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('-1'),
                    [u2]: toWei('1'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('1'),
                    [u2]: toWei('-1'),
                    [relayer]: toWei('0')
                }
            }
        };

        await limitAndMarketTestMatch(testConfig);
    });

    it('match with market balance', async () => {
        const testConfig = {
            userBalancePaths: {
                [u1]: {
                    category: 1,
                    marketID: 0,
                    user: u1
                },
                [u2]: {
                    category: 0,
                    marketID: 0,
                    user: u2
                }
            },
            baseAssetFilledAmounts: [toWei('1')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(20)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 0,
                asTakerFeeRate: 0,
                baseAssetAmount: toWei('1'),
                quoteAssetAmount: toWei('1'),
                gasTokenAmount: toWei('0'),
                balancePath: {
                    category: 1,
                    marketID: 0,
                    user: u1
                }
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 0,
                    asMakerFeeRate: 0,
                    asTakerFeeRate: 0,
                    quoteAssetAmount: toWei('1'),
                    baseAssetAmount: toWei('1'),
                    gasTokenAmount: toWei('0')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('-1'),
                    [u2]: toWei('1'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('1'),
                    [u2]: toWei('-1'),
                    [relayer]: toWei('0')
                }
            }
        };

        await limitAndMarketTestMatch(testConfig);
    });

    it('match with market balance with temporary liquidatable should be fine', async () => {
        const testConfig = {
            userBalancePaths: {
                [u1]: {
                    category: 1,
                    marketID: 0,
                    user: u1
                },
                [u2]: {
                    category: 0,
                    marketID: 0,
                    user: u2
                }
            },
            baseAssetFilledAmounts: [toWei('100')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                oraclePrice: toWei('0.1'),
                initBalances: {
                    [u1]: toWei(75),
                    [u2]: toWei(25)
                }
            },
            quoteAssetConfig: {
                name: 'Ethereum',
                symbol: 'ETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10)
                }
            },
            beforeMatch: async ({ baseAsset }) => {
                // scenario
                // u2 supply 25 TT into pool
                // u1 borrow 25 TT by using 75 TT as collateral
                await supply(baseAsset.address, toWei('25'), {
                    from: u2
                });
                await borrow(0, baseAsset.address, toWei('25'), {
                    from: u1
                });
                // now the u1 has 100 TT balances and 25 TT debt
                // assert.equal(await hydro.marketBalanceOf(0, baseAsset.address, u1), toWei('100'));
                // During the exchange process, the taker will transfer baseToken to maker first.
                // Before the maker transfer quote tokens back, the taker's collateral account is
                // in a liquidatable status. But it's reasonable as the transaction is atomic.
                // We should only care about the finial collateral account is liquidatable or not.
                // The temporary liquidatable state doesn't not matter.
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 0,
                asTakerFeeRate: 0,
                baseAssetAmount: toWei('100'),
                quoteAssetAmount: toWei('10'),
                gasTokenAmount: toWei('0'),
                balancePath: {
                    category: 1,
                    marketID: 0,
                    user: u1
                }
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 0,
                    asMakerFeeRate: 0,
                    asTakerFeeRate: 0,
                    quoteAssetAmount: toWei('10'),
                    baseAssetAmount: toWei('100'),
                    gasTokenAmount: toWei('0')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('-100'),
                    [u2]: toWei('100'),
                    [relayer]: toWei('0')
                },
                ETH: {
                    [u1]: toWei('10'),
                    [u2]: toWei('-10'),
                    [relayer]: toWei('0')
                }
            }
        };

        await limitAndMarketTestMatch(testConfig);
    });

    it('match with market balance results in liquidatable should be reverted', async () => {
        const testConfig = {
            userBalancePaths: {
                [u1]: {
                    category: 1,
                    marketID: 0,
                    user: u1
                },
                [u2]: {
                    category: 0,
                    marketID: 0,
                    user: u2
                }
            },
            baseAssetFilledAmounts: [toWei('100')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                oraclePrice: toWei('100'), // <= note, the base Asset is expensive
                initBalances: {
                    [u1]: toWei(75),
                    [u2]: toWei(25)
                }
            },
            quoteAssetConfig: {
                name: 'Ethereum',
                symbol: 'ETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10)
                }
            },
            beforeMatch: async ({ baseAsset }) => {
                // scenario
                // u2 supply 25 TT into pool
                // u1 borrow 25 TT by using 75 TT as collateral
                await supply(baseAsset.address, toWei('25'), {
                    from: u2
                });
                await borrow(0, baseAsset.address, toWei('25'), {
                    from: u1
                });
                // now the u1 has 100 TT balances and 25 TT debt
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 0,
                asTakerFeeRate: 0,
                baseAssetAmount: toWei('100'),
                quoteAssetAmount: toWei('10'),
                gasTokenAmount: toWei('0'),
                balancePath: {
                    category: 1,
                    marketID: 0,
                    user: u1
                }
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 0,
                    asMakerFeeRate: 0,
                    asTakerFeeRate: 0,
                    quoteAssetAmount: toWei('10'),
                    baseAssetAmount: toWei('100'),
                    gasTokenAmount: toWei('0')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('-100'),
                    [u2]: toWei('100'),
                    [relayer]: toWei('0')
                },
                ETH: {
                    [u1]: toWei('10'),
                    [u2]: toWei('-10'),
                    [relayer]: toWei('0')
                }
            }
        };

        await assert.rejects(
            limitAndMarketTestMatch(testConfig),
            /COLLATERAL_ACCOUNT_LIQUIDATABLE/
        );
    });

    it('match with a not participant relayer', async () => {
        await hydro.exitIncentiveSystem({ from: relayer });

        const testConfig = {
            baseAssetFilledAmounts: [toWei('1')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(20)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 0,
                asTakerFeeRate: 0,
                baseAssetAmount: toWei('1'),
                quoteAssetAmount: toWei('1'),
                gasTokenAmount: toWei('0')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 0,
                    asMakerFeeRate: 0,
                    asTakerFeeRate: 0,
                    quoteAssetAmount: toWei('1'),
                    baseAssetAmount: toWei('1'),
                    gasTokenAmount: toWei('0')
                }
            ],
            assertDiffs: {
                TT: {
                    [u1]: toWei('-1'),
                    [u2]: toWei('1'),
                    [relayer]: toWei('0')
                },
                WETH: {
                    [u1]: toWei('1'),
                    [u2]: toWei('-1'),
                    [relayer]: toWei('0')
                }
            }
        };

        await limitAndMarketTestMatch(testConfig);
    });

    it('match with a expired order will revert', async () => {
        const testConfig = {
            baseAssetFilledAmounts: [toWei('1')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(20)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 1, // <- already expired
                asMakerFeeRate: 0,
                asTakerFeeRate: 0,
                baseAssetAmount: toWei('1'),
                quoteAssetAmount: toWei('1'),
                gasTokenAmount: toWei('0')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 0,
                    asMakerFeeRate: 0,
                    asTakerFeeRate: 0,
                    quoteAssetAmount: toWei('1'),
                    baseAssetAmount: toWei('1'),
                    gasTokenAmount: toWei('0')
                }
            ]
        };

        await assert.rejects(limitAndMarketTestMatch(testConfig), /ORDER_IS_NOT_FILLABLE/);
    });

    it('match with a canceled order will revert', async () => {
        const testConfig = {
            baseAssetFilledAmounts: [toWei('1')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(20)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'sell',
                type: 'limit',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 0,
                asTakerFeeRate: 0,
                baseAssetAmount: toWei('1'),
                quoteAssetAmount: toWei('1'),
                gasTokenAmount: toWei('0')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'buy',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 0,
                    asMakerFeeRate: 0,
                    asTakerFeeRate: 0,
                    quoteAssetAmount: toWei('1'),
                    baseAssetAmount: toWei('1'),
                    gasTokenAmount: toWei('0')
                }
            ],
            beforeMatch: async ({ takerOrder, orderAddressSet }) => {
                // cancel taker order before match
                const takerOrderClone = { ...clone(takerOrder), ...orderAddressSet };
                await hydro.cancelOrder(takerOrderClone, { from: takerOrderClone.trader });
            }
        };

        await assert.rejects(limitAndMarketTestMatch(testConfig), /ORDER_IS_NOT_FILLABLE/);
    });

    it('match with a full filled market buy order will revert', async () => {
        const testConfig = {
            baseAssetFilledAmounts: [toWei('1')],
            baseAssetConfig: {
                name: 'TestToken',
                symbol: 'TT',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(20)
                }
            },
            quoteAssetConfig: {
                name: 'Wrapped Ethereum',
                symbol: 'WETH',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(10)
                }
            },
            takerOrderParam: {
                trader: u1,
                relayer,
                version: 2,
                side: 'buy',
                type: 'market',
                expiredAtSeconds: 3500000000,
                asMakerFeeRate: 0,
                asTakerFeeRate: 0,
                baseAssetAmount: toWei('0'),
                quoteAssetAmount: toWei('1'),
                gasTokenAmount: toWei('0')
            },
            makerOrdersParams: [
                {
                    trader: u2,
                    relayer,
                    version: 2,
                    side: 'sell',
                    type: 'limit',
                    expiredAtSeconds: 3500000000,
                    makerRebateRate: 0,
                    asMakerFeeRate: 0,
                    asTakerFeeRate: 0,
                    quoteAssetAmount: toWei('1'),
                    baseAssetAmount: toWei('1'),
                    gasTokenAmount: toWei('0')
                }
            ],
            afterMatch: async ({
                takerOrder,
                makerOrders,
                baseAssetFilledAmounts,
                orderAddressSet
            }) => {
                // match again
                await hydro.matchOrders(
                    {
                        takerOrderParam: takerOrder,
                        makerOrderParams: makerOrders,
                        baseAssetFilledAmounts: baseAssetFilledAmounts,
                        orderAddressSet
                    },
                    { from: relayer }
                );
            }
        };

        await assert.rejects(matchTest(testConfig), /ORDER_IS_NOT_FILLABLE/);
    });
});
