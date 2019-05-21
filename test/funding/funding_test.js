const assert = require('assert');
const { getFundingContracts, newContract } = require('../utils');
const { generateFundingOrderData } = require('../../sdk/sdk');

const BigNumber = require('bignumber.js');
const TestToken = artifacts.require('./helper/TestToken.sol');
// const { generateOrderData, getOrderHash } = require('../../sdk/sdk');

const weis = new BigNumber('1000000000000000000');
const infinity = '999999999999999999999999999999999999999999';

const toWei = x => {
    return new BigNumber(x).times(weis).toString();
};

contract('Funding', accounts => {
    let funding, proxy, oracle;

    const relayer = accounts[9];

    const u1 = accounts[4];
    const u2 = accounts[5];
    const u3 = accounts[6];

    const users = [u1, u2, u3, relayer];

    beforeEach(async () => {
        const contracts = await getFundingContracts();
        funding = contracts.funding;
        proxy = contracts.proxy;
        oracle = contracts.oracle;
    });

    const initToken = async tokenConfig => {
        const { initBalances, initCollaterals, etherPrice } = tokenConfig;

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

        if (etherPrice) {
            // set oracle price
            await oracle.methods
                .setTokenPriceInEther(
                    token._address,
                    new BigNumber(etherPrice).times('1000000000000000000').toString()
                )
                .send({ from: accounts[0] });
        }

        // console.log(
        //     token._address,
        //     await oracle.methods.getTokenPriceInEther(token._address).call()
        // );

        await funding.methods
            .addAsset(token._address, 1) // TODO 1.5
            .send({ from: accounts[0], gasLimit: 10000000 });

        for (let j = 0; j < Object.keys(initBalances).length; j++) {
            const userKey = Object.keys(initBalances)[j];
            const user = userKey;
            const amount = initBalances[userKey];

            if (tokenConfig.symbol == 'ETH') {
                await proxy.methods
                    .deposit('0x0000000000000000000000000000000000000000', amount)
                    .send({ from: user, value: amount });
            } else {
                await token.methods.transfer(user, amount).send({ from: relayer });
                await token.methods.approve(proxy._address, amount).send({ from: user });
                await proxy.methods.deposit(token._address, amount).send({ from: user });
            }
        }

        if (initCollaterals) {
            for (let j = 0; j < Object.keys(initCollaterals).length; j++) {
                const userKey = Object.keys(initCollaterals)[j];
                const user = userKey;
                const amount = initCollaterals[userKey];

                await funding.methods
                    .depositCollateralFromProxy(token._address, user, amount)
                    .send({ from: user });
            }
        }

        return token;
    };
    const buildOrder = async (params, asset) => {
        const order = {
            owner: params.owner,
            relayer,
            asset,
            amount: params.amount,
            data: generateFundingOrderData(
                params.side,
                params.expiredAt,
                params.durating,
                params.interestRate,
                params.feeRate,
                Math.round(Math.random() * 10000000)
            )
        };
        return order;
    };

    const initTokens = async configs => {
        const tokens = await Promise.all(configs.map(config => initToken(config)));
        const res = {};
        tokens.forEach(token => (res[token.symbol] = token._address));
        return res;
    };

    const getTokensUsersBalances = async tokens => {
        const res = {};
        tokens['ETH'] = '0x0000000000000000000000000000000000000000';

        const symbols = Object.keys(tokens);

        for (let j = 0; j < symbols.length; j++) {
            const symbol = symbols[j];
            const tokenAddress = tokens[symbol];

            for (let i = 0; i < users.length; i++) {
                const user = users[i];
                const balance = await proxy.methods.balanceOf(tokenAddress, user).call();
                res[`${symbol}-${user}`] = balance;
            }
        }

        return res;
    };

    const assetProxyBalances = async (tokens, balances, messagePrefix) => {
        const balanceTokens = Object.keys(balances);
        for (let i = 0; i < balanceTokens.length; i++) {
            const tokenAddress = tokens[balanceTokens[i]];
            const users = Object.keys(balances[balanceTokens[i]]);
            for (let j = 0; j < users.length; j++) {
                const user = users[j];
                const expectedBalance = balances[balanceTokens[i]][user];
                const actualBalance = await proxy.methods.balanceOf(tokenAddress, user).call();
                assert.equal(
                    actualBalance,
                    expectedBalance,
                    `${messagePrefix} Expect proxy balance ${tokenAddress} token for ${user} to be ${expectedBalance}, but actual is ${actualBalance}`
                );
            }
        }
    };

    const assetCollaterals = async (tokens, collaterals, messagePrefix) => {
        const collateralTokens = Object.keys(collaterals);
        for (let i = 0; i < collateralTokens.length; i++) {
            const tokenAddress = tokens[collateralTokens[i]];
            const users = Object.keys(collaterals[collateralTokens[i]]);
            for (let j = 0; j < users.length; j++) {
                const user = users[j];
                const expectedBalance = collaterals[collateralTokens[i]][user];
                const actualBalance = await funding.methods
                    .collateralBalanceOf(tokenAddress, user)
                    .call();
                assert.equal(
                    actualBalance,
                    expectedBalance,
                    `${messagePrefix} Expect collaterals balance ${tokenAddress} token for ${user} to be ${expectedBalance}, but actual is ${actualBalance}`
                );
            }
        }
    };

    const assertCollateralStatus = async (collateralStatus, prefixMessage) => {
        const users = Object.keys(collateralStatus);
        for (let i = 0; i < users.length; i++) {
            const user = users[i];
            const collateralStateRes = await funding.methods.getUserLoansState(user).call();

            // bool       liquidable;
            // uint256[]  userAssets;
            // Loan[]     loans;
            // uint256[]  loanValues;
            // uint256    loansTotalValue;
            // uint256    collateralsTotalValue;

            const collateralState = collateralStateRes;

            // console.log(collateralState);

            assert.equal(
                collateralState.loansTotalValue,
                collateralStatus[user].loansTotalValue,
                `${prefixMessage} collateralStatus loansTotalValue not equal: expected ${
                    collateralState.loansTotalValue
                } actual: ${collateralStatus[user].loansTotalValue}`
            );

            assert.equal(
                collateralState.collateralsTotalValue,
                collateralStatus[user].collateralsTotalValue,
                `${prefixMessage} collateralStatus collateralsTotalValue not equal: expected ${
                    collateralState.collateralsTotalValue
                } actual: ${collateralStatus[user].collateralsTotalValue}`
            );
        }
    };

    const testFundingMatch = async config => {
        const {
            tokenConfigs,
            takerOrderParam,
            makerOrdersParams,
            filledAmounts,
            beforeMatchProxyBalances,
            beforeMatchCollateralStatus,
            beforeMatchCollaterals,
            afterMatchProxyBalances,
            afterMatchCollateralStatus,
            assertDiffs,
            baseTokenFilledAmounts,
            allowPrecisionError,
            assertFilled
        } = config;
        const tokens = await initTokens(tokenConfigs);

        await assetProxyBalances(tokens, beforeMatchProxyBalances, 'Before Match');
        await assetCollaterals(tokens, beforeMatchCollaterals, 'Before Match');

        // const balancesBeforeMatch = await getTokensUsersBalances(tokens);
        // console.log(balancesBeforeMatch);

        const asset = tokens[takerOrderParam.asset];
        const takerOrder = await buildOrder(takerOrderParam, asset);
        // console.log(takerOrder);

        const makerOrders = [];
        for (let i = 0; i < makerOrdersParams.length; i++) {
            makerOrders.push(await buildOrder(makerOrdersParams[i], asset));
        }
        // console.log(makerOrders);

        if (beforeMatchCollateralStatus) {
            await assertCollateralStatus(beforeMatchCollateralStatus, 'Before Match');
        }

        const res = await funding.methods
            .matchOrders(takerOrder, makerOrders, filledAmounts)
            .send({ from: relayer, gas: 10000000, gasLimit: 10000000 });
        console.log(`        ${makerOrders.length} Orders, Gas Used:`, res.gasUsed);

        await assetProxyBalances(tokens, afterMatchProxyBalances, 'After Match');

        if (afterMatchCollateralStatus) {
            await assertCollateralStatus(afterMatchCollateralStatus, 'After Match');
        }

        // const balancesAfterMatch = await getTokensUsersBalances(tokens);

        // await getTokenUsersBalances(baseToken, users, balancesAfterMatch);
        // await getTokenUsersBalances(quoteToken, users, balancesAfterMatch);
        // for (let i = 0; i < Object.keys(assertDiffs).length; i++) {
        //     const tokenSymbol = Object.keys(assertDiffs)[i];

        //     for (let j = 0; j < Object.keys(assertDiffs[tokenSymbol]).length; j++) {
        //         const userKey = Object.keys(assertDiffs[tokenSymbol])[j];
        //         const expectedDiff = assertDiffs[tokenSymbol][userKey];
        //         const balanceKey = `${tokenSymbol}-${userKey}`;
        //         const actualDiff = new BigNumber(balancesAfterMatch[balanceKey]).minus(
        //             balancesBeforeMatch[balanceKey]
        //         );

        //         assertEqual(
        //             actualDiff.toString(),
        //             expectedDiff,
        //             allowPrecisionError,
        //             `${balanceKey}`
        //         );
        //     }
        // }

        // if (assertFilled) {
        //     const { limitTaker, marketTaker, makers } = assertFilled;

        //     if (limitTaker && takerOrderParam.type == 'limit') {
        //         assertEqual(
        //             await exchange.methods.filled(takerOrder.orderHash).call(),
        //             limitTaker,
        //             allowPrecisionError
        //         );
        //     }

        //     if (marketTaker && takerOrderParam.type == 'market') {
        //         assertEqual(
        //             await exchange.methods.filled(takerOrder.orderHash).call(),
        //             marketTaker,
        //             allowPrecisionError
        //         );
        //     }

        //     if (makers) {
        //         for (let i = 0; i < makers.length; i++) {
        //             assertEqual(
        //                 await exchange.methods.filled(makerOrders[i].orderHash).call(),
        //                 makers[i],
        //                 allowPrecisionError
        //             );
        //         }
        //     }
        // }
    };

    beforeEach(async () => {
        // reset the orcale
        //
        // set ETH price to 1000 USD
        // set HOT price to 0.1 USD
    });

    // User2 pledge 1 ETH (1000 USD) and 5000 HOT (500 USD) as collateral
    // User1 lend   500 USD
    // User2 borrow 500 USD
    // Interest 10%, 2 years, fee 10%
    it('taker borrow, full match', async () => {
        const testConfig = {
            asset: 'USD',
            filledAmounts: [toWei('500')],
            tokenConfigs: [
                {
                    symbol: 'ETH',
                    initBalances: {
                        [u2]: toWei(1)
                    },
                    initCollaterals: {
                        [u2]: toWei(1)
                    }
                },
                {
                    name: 'USD',
                    etherPrice: '0.001',
                    symbol: 'USD',
                    decimals: 18,
                    initBalances: {
                        [u1]: toWei(500), // user1 capital
                        [u2]: toWei(100) // for user2 to pay interest
                    }
                },
                {
                    name: 'HOT',
                    etherPrice: '0.0001',
                    symbol: 'HOT',
                    decimals: 18,
                    initBalances: {
                        [u2]: toWei(5000) // for user2 to pledge
                    },
                    initCollaterals: {
                        [u2]: toWei(5000) // for user2 to pledge
                    }
                }
            ],
            beforeMatchCollateralStatus: {
                [u1]: {
                    loansTotalValue: '0',
                    collateralsTotalValue: '0'
                },
                [u2]: {
                    loansTotalValue: '0',
                    collateralsTotalValue: '1500000000000000000000000000000000000'
                }
            },
            beforeMatchProxyBalances: {
                USD: {
                    [u1]: toWei('500'),
                    [u2]: toWei('100')
                }
            },
            beforeMatchCollaterals: {
                ETH: {
                    [u2]: toWei(1)
                },
                HOT: {
                    [u2]: toWei('5000')
                }
            },
            takerOrderParam: {
                owner: u2,
                side: 'borrow',
                expiredAt: 3500000000,
                durating: 3500000000,
                asset: 'USD',
                interestRate: 0,
                feeRate: 0,
                amount: toWei('500')
            },
            makerOrdersParams: [
                {
                    owner: u1,
                    side: 'lend',
                    expiredAt: 3500000000,
                    durating: 3500000000,
                    asset: 'USD',
                    interestRate: 0,
                    feeRate: 0,
                    amount: toWei('500')
                }
            ],
            afterMatchCollateralStatus: {
                [u1]: {
                    loansTotalValue: '0',
                    collateralsTotalValue: '0'
                },
                [u2]: {
                    loansTotalValue: '500000000000000000000000000000000000',
                    collateralsTotalValue: '1500000000000000000000000000000000000'
                }
            },
            afterMatchProxyBalances: {
                USD: {
                    [u1]: toWei('0'),
                    [u2]: toWei('600')
                }
            }
            // assertDiffs: {
            //     HOT: {
            //         u1: toWei('-20'),
            //         u2: toWei('10'),
            //         relayer: toWei('0')
            //     },
            //     USD: {
            //         u1: toWei('-20'),
            //         u2: toWei('10'),
            //         relayer: toWei('0')
            //     },
            //     ETH: {
            //         u1: toWei('3.415'),
            //         u2: toWei('-2.019'),
            //         relayer: toWei('0.522')
            //     }
            // },
            // assertFilledDuringLending: {
            //     // limitTaker: toWei('20'),
            //     // marketTaker: toWei('20'),
            //     // makers: [toWei('10'), toWei('10')]
            // },
            // assertFilledAfterLending: {
            //     // limitTaker: toWei('20'),
            //     // marketTaker: toWei('20'),
            //     // makers: [toWei('10'), toWei('10')]
            // }
        };

        await testFundingMatch(testConfig);
    });
});
