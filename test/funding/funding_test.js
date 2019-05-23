const assert = require('assert');
const { getFundingContracts, newContract } = require('../utils');
const { generateFundingOrderData, getFundingOrderHash } = require('../../sdk/sdk');

const BigNumber = require('bignumber.js');
const TestToken = artifacts.require('./helper/TestToken.sol');
// const { generateOrderData, getOrderHash } = require('../../sdk/sdk');

const weis = new BigNumber('1000000000000000000');

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

    const makeSnapshot = () =>
        new Promise((resolve, reject) => {
            web3.currentProvider.send(
                {
                    method: 'evm_snapshot',
                    params: [],
                    jsonrpc: '2.0',
                    id: new Date().getTime()
                },
                (error, result) => {
                    if (error) {
                        reject(error);
                    }

                    resolve(result.result);
                }
            );
        });

    const mineEmptyBlock = async count => {
        const mine = () =>
            new Promise((resolve, reject) => {
                web3.currentProvider.send(
                    {
                        method: 'evm_mine',
                        params: [],
                        jsonrpc: '2.0',
                        id: new Date().getTime()
                    },
                    (error, result) => {
                        if (error) {
                            reject(error);
                        }

                        resolve(result.result);
                    }
                );
            });

        const finish = [];

        for (let i = 0; i < count; i++) {
            finish.push(mine());
        }

        return Promise.all(finish);
    };

    const updateTimestamp = timestamp =>
        new Promise((resolve, reject) => {
            web3.currentProvider.send(
                {
                    method: 'evm_mine',
                    params: [timestamp],
                    jsonrpc: '2.0',
                    id: new Date().getTime()
                },
                (error, result) => {
                    if (error) {
                        reject(error);
                    }

                    resolve(result.result);
                }
            );
        });

    const recoverSnapshot = snapshotID =>
        new Promise((resolve, reject) => {
            web3.currentProvider.send(
                {
                    method: 'evm_revert',
                    params: [snapshotID],
                    jsonrpc: '2.0',
                    id: new Date().getTime()
                },
                (error, result) => {
                    if (error) {
                        reject(error);
                    }

                    resolve(result.result);
                }
            );
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

    const pp = obj => {
        console.log(JSON.stringify(obj, null, 2));
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
                    `${messagePrefix} ${getUserID(user)} proxy balance ${tokenAddress}`
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

    const changeTokenPrice = async (tokens, tokenPrices) => {
        const symbols = Object.keys(tokenPrices);
        // console.log(tokens, tokenPrices);
        for (let i = 0; i < symbols.length; i++) {
            await oracle.methods
                .setTokenPriceInEther(
                    tokens[symbols[i]],
                    new BigNumber(tokenPrices[symbols[i]]).times('1000000000000000000').toString()
                )
                .send({ from: accounts[0] });
        }
    };

    const getUserID = address => {
        if (address === u1) {
            return 'u1';
        } else if (address === u2) {
            return 'u2';
        } else if (address === u3) {
            return 'u3';
        } else if (address === relayer) {
            return 'relayer';
        }
    };

    const assertCollateralStatus = async (collateralStatus, prefixMessage) => {
        const users = Object.keys(collateralStatus);
        for (let i = 0; i < users.length; i++) {
            const user = users[i];
            const collateralState = await funding.methods.getUserLoansState(user).call();

            // bool       liquidable;
            // uint256[]  userAssets;
            // Loan[]     loans;
            // uint256[]  loanValues;
            // uint256    loansTotalValue;
            // uint256    collateralsTotalValue;

            // console.log(collateralState);

            assert.equal(
                collateralState.loansTotalValue,
                collateralStatus[user].loansTotalValue,
                `${prefixMessage} collateralStatus loansTotalValue ${getUserID(user)}`
            );

            assert.equal(
                collateralState.collateralsTotalValue,
                collateralStatus[user].collateralsTotalValue,
                `${prefixMessage} collateralStatus collateralsTotalValue ${getUserID(user)}`
            );
        }
    };

    const assertLiquidable = async user => {
        const collateralState = await funding.methods.getUserLoansState(user).call();
        assert.ok(collateralState.liquidable);
    };

    const assertOrderFilledAmount = async (orderHash, amount, prefixMessage) => {
        const actualAmount = await funding.methods.getOrderFilledAmount(orderHash).call();
        assert.equal(amount, actualAmount, `${prefixMessage} Order Filled Amount`);
    };

    const assertBatchStatus = async (status, tokens, prefix) => {
        const { proxyBalances, collateralStatus, collaterals } = status;

        if (proxyBalances) {
            await assetProxyBalances(tokens, proxyBalances, prefix);
        }

        if (collateralStatus) {
            await assertCollateralStatus(collateralStatus, prefix);
        }

        if (collaterals) {
            await assetCollaterals(tokens, collaterals, prefix);
        }
    };

    const runInSandbox = async (fn, timestamp) => {
        let snapshotID;

        try {
            snapshotID = await makeSnapshot();
            // let currentBlockNumber = await web3.eth.getBlockNumber();
            // let currentBlock = await web3.eth.getBlock(currentBlockNumber);
            // console.log('CurrentBlock', currentBlockNumber, currentBlock.timestamp);

            if (timestamp) {
                // await updateTimestamp(timestamp);
                await funding.methods.setBlockTimestamp(timestamp).send({ from: accounts[0] });
            }

            // currentBlockNumber = await web3.eth.getBlockNumber();
            // currentBlock = await web3.eth.getBlock(currentBlockNumber);
            // console.log('CurrentBlock', currentBlockNumber, currentBlock.timestamp);

            await fn();
            // console.log('snapshotID', snapshotID);
        } finally {
            // console.log(`recover snapshot ${snapshotID}`);
            const result = await recoverSnapshot(snapshotID);
            if (!result) {
                return 'recover snapshot failed';
            }
        }
    };

    const testFundingMatch = async config => {
        const {
            tokenConfigs,
            takerOrderParam,
            makerOrdersParams,
            filledAmounts,
            beforeMatchStatus,
            afterMatchStatus,
            results
        } = config;

        // prepare all tokens and initialized status
        const tokens = await initTokens(tokenConfigs);
        pp(tokens);

        // assert status before match
        if (beforeMatchStatus) {
            await assertBatchStatus(beforeMatchStatus, tokens, 'Before Match');
        }

        // assert taker order filled amount before match
        const asset = tokens[takerOrderParam.asset];
        const takerOrder = await buildOrder(takerOrderParam, asset);
        takerOrder.hash = getFundingOrderHash(takerOrder);
        await assertOrderFilledAmount(takerOrder.hash, 0, 'Before Match, taker Order');
        // console.log(takerOrder);

        // assert maker order filled amount before match
        const makerOrders = [];
        for (let i = 0; i < makerOrdersParams.length; i++) {
            const order = await buildOrder(makerOrdersParams[i], asset);
            order.hash = getFundingOrderHash(order);
            makerOrders.push(order);
            await assertOrderFilledAmount(order.hash, 0, `Before Match, maker Order #${i}`);
        }
        // console.log(makerOrders);

        const res = await funding.methods
            .matchOrders(takerOrder, makerOrders, filledAmounts)
            .send({ from: relayer, gas: 10000000, gasLimit: 10000000 });
        console.log(`        ${makerOrders.length} Orders, Gas Used:`, res.gasUsed);
        const loanID = res.events.NewLoan.returnValues.loanID;
        const loan = await funding.methods.allLoans(loanID).call();
        // console.log(loan);
        const loanStartAt = parseInt(loan.startAt, 10);

        // lock the time to loan created time to avoid timestamp mismatch
        await funding.methods.setBlockTimestamp(loanStartAt).send({ from: accounts[0] });

        // assert after match
        if (afterMatchStatus) {
            await assertBatchStatus(afterMatchStatus, tokens, 'After Match');
        }

        const totalAmount = filledAmounts
            .reduce((acc, x) => (acc = acc.plus(new BigNumber(x))), new BigNumber('0'))
            .toString();

        // assert taker order filled amount after match
        await assertOrderFilledAmount(takerOrder.hash, totalAmount, 'After Match taker order');

        // assert maker orders filled amount after match
        for (let i = 0; i < makerOrders.length; i++) {
            const order = makerOrders[i];
            await assertOrderFilledAmount(
                order.hash,
                filledAmounts[i],
                `After Match, maker Order #${i}`
            );
        }

        if (!results) {
            return;
        }

        const { repay, liquidition } = results;

        if (repay) {
            await runInSandbox(async () => {
                if (repay.tokenPrices) {
                    await changeTokenPrice(tokens, repay.tokenPrices);
                }

                await assertBatchStatus(repay.before, tokens, 'repay before');
                // repay
                await funding.methods
                    .repayLoanPublic(loanID, totalAmount)
                    .send({ from: takerOrder.owner, gasLimit: 999999999 });

                await assertBatchStatus(repay.after, tokens, 'repay after');
            }, loanStartAt + repay.duration);
        }

        if (liquidition) {
            const borrower =
                takerOrderParam.side === 'borrow'
                    ? takerOrderParam.owner
                    : makerOrdersParams[0].owner;

            await runInSandbox(async () => {
                if (liquidition.tokenPrices) {
                    await changeTokenPrice(tokens, liquidition.tokenPrices);
                }

                await assertBatchStatus(liquidition.before, tokens, 'liquidition before');

                await assertLiquidable(borrower);

                let res = await funding.methods
                    .liquidateUser(borrower)
                    .send({ from: accounts[0], gasLimit: 20000000 });

                // console.log(JSON.stringify(res));
                const auctionID = res.events.AuctionCreated.returnValues.auctionID;
                // console.log(await funding.methods.allAuctions(auctionID).call());

                await mineEmptyBlock(liquidition.auctionRatio * 100 - 1);

                // console.log(await funding.methods.allAuctions(auctionID).call());

                res = await funding.methods
                    .claimAuction(auctionID)
                    .send({ from: liquidition.filledBy, gasLimit: 999999999 });

                // pp(res);

                await assertBatchStatus(liquidition.after, tokens, 'liquidition after');
            }, loanStartAt + liquidition.duration);
        }
    };

    beforeEach(async () => {
        // reset the orcale
        //
        // set ETH price to 1000 USD
        // set HOT price to 0.1 USD
    });

    afterEach(async () => {
        await funding.methods.setBlockTimestamp(0).send({ from: accounts[0] });
    });

    // User2 pledge 1 ETH (1000 USD) and 5000 HOT (500 USD) as collateral
    // User1 lend   500 USD
    // User2 borrow 500 USD
    // User3        1000 USD fill auction
    // Interest 10%, 2 years, fee 10%
    it('taker borrow, full match', async () => {
        const testConfig = {
            asset: 'USD',
            filledAmounts: [toWei('500')],
            tokenConfigs: [
                {
                    symbol: 'ETH',
                    initBalances: {
                        [u2]: toWei('1')
                    },
                    initCollaterals: {
                        [u2]: toWei('1')
                    }
                },
                {
                    name: 'USD',
                    etherPrice: '0.001',
                    symbol: 'USD',
                    decimals: 18,
                    initBalances: {
                        [u1]: toWei(500), // user1 capital
                        [u2]: toWei(100), // for user2 to pay interest
                        [u3]: toWei(1000)
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
            beforeMatchStatus: {
                proxyBalances: {
                    ETH: {
                        [u1]: toWei('0'),
                        [u2]: toWei('0'),
                        [u3]: toWei('0'),
                        [relayer]: toWei('0')
                    },
                    USD: {
                        [u1]: toWei('500'),
                        [u2]: toWei('100'),
                        [u3]: toWei('1000'),
                        [relayer]: toWei('0')
                    },
                    HOT: {
                        [u1]: toWei('0'),
                        [u2]: toWei('0'),
                        [u3]: toWei('0'),
                        [relayer]: toWei('0')
                    }
                },
                collateralStatus: {
                    [u2]: {
                        loansTotalValue: '0',
                        collateralsTotalValue: toWei('1.5')
                    }
                },
                collaterals: {
                    ETH: {
                        [u2]: toWei('1')
                    },
                    HOT: {
                        [u2]: toWei('5000')
                    }
                }
            },
            takerOrderParam: {
                owner: u2,
                side: 'borrow',
                expiredAt: 3500000000,
                durating: 3500000000,
                asset: 'USD',
                interestRate: 1000, // 10%
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
                    interestRate: 1000, // 10%
                    feeRate: 1500, // 15%
                    amount: toWei('500')
                }
            ],
            afterMatchStatus: {
                proxyBalances: {
                    ETH: {
                        [u1]: toWei('0'),
                        [u2]: toWei('0'),
                        [u3]: toWei('0'),
                        [relayer]: toWei('0')
                    },
                    USD: {
                        [u1]: toWei('0'),
                        [u2]: toWei('600'),
                        [u3]: toWei('1000'),
                        [relayer]: toWei('0')
                    },
                    HOT: {
                        [u1]: toWei('0'),
                        [u2]: toWei('0'),
                        [u3]: toWei('0'),
                        [relayer]: toWei('0')
                    }
                },
                collateralStatus: {
                    [u2]: {
                        loansTotalValue: toWei('0.5'),
                        collateralsTotalValue: toWei('1.5')
                    }
                },
                collaterals: {
                    ETH: {
                        [u2]: toWei('1')
                    },
                    HOT: {
                        [u2]: toWei('5000')
                    }
                }
            },
            results: {
                repay: {
                    duration: 86400 * 100,
                    tokenPrices: {},
                    before: {
                        collateralStatus: {
                            [u2]: {
                                loansTotalValue: toWei('0.513698630136986301'), // 500(USD) * 10%(InterestRate) * 100(duration) / 365(days of year) / 1000 (Eth USD price)
                                collateralsTotalValue: toWei('1.5')
                            }
                        },
                        collaterals: {
                            ETH: {
                                [u2]: toWei('1')
                            },
                            HOT: {
                                [u2]: toWei('5000')
                            }
                        }
                    },
                    after: {
                        proxyBalances: {
                            USD: {
                                [u1]: toWei('511.643835616438356164'), // interest excluded fee: 500(USD) + 500(USD) * 10%(InterestRate) * 100(duration) * 0.85(15% relayer fee) / 365(days of year)
                                [u2]: toWei('86.301369863013698631'), // interest: 100(USD) - 500(USD) * 10%(InterestRate) * 100(duration) / 365(days of year)
                                [relayer]: toWei('2.054794520547945205') // fee: 500 * 10% * 100 * 0.15 / 365
                            }
                        },
                        collateralStatus: {
                            [u2]: {
                                loansTotalValue: toWei('0'), // no debt any more
                                collateralsTotalValue: toWei('1.5')
                            }
                        },
                        collaterals: {
                            ETH: {
                                [u2]: toWei('1')
                            },
                            HOT: {
                                [u2]: toWei('5000')
                            }
                        }
                    }
                },
                liquidition: {
                    duration: 86400 * 720,
                    filledBy: u3,
                    tokenPrices: {
                        HOT: '0',
                        USD: '0.00125' // 800 USD
                    },
                    auctionRatio: 0.6,
                    before: {
                        collateralStatus: {
                            [u2]: {
                                loansTotalValue: toWei('0.748287671232876712'), // (500 + 500 * 0.1 * 720 / 365) * 0.00125
                                collateralsTotalValue: toWei('1')
                            }
                        },
                        collaterals: {
                            ETH: {
                                [u2]: toWei('1')
                            },
                            HOT: {
                                [u2]: toWei('5000')
                            }
                        }
                    },
                    after: {
                        proxyBalances: {
                            USD: {
                                [u1]: toWei('583.835616438356164384'), // 500(USD) + 500(USD) * 10%(InterestRate) * 720(duration) * 0.85(15% relayer fee) / 365(days of year)
                                [u2]: toWei('600'),
                                [u3]: toWei('401.369863013698630137'), // 1000 - 500 * 10% * 720 / 365 - 500
                                [relayer]: toWei('14.794520547945205479') // 500 * 10% * 720 * 0.15 / 365
                            },
                            ETH: {
                                [u1]: toWei('0'),
                                [u2]: toWei('0'),
                                [u3]: toWei('0.6'), // by filling auction
                                [relayer]: toWei('0')
                            },
                            HOT: {
                                [u1]: toWei('0'),
                                [u2]: toWei('0'),
                                [u3]: toWei('3000'), // by filling auction
                                [relayer]: toWei('0')
                            }
                        },
                        collaterals: {
                            ETH: {
                                [u2]: toWei('0.4')
                            },
                            HOT: {
                                [u2]: toWei('2000')
                            }
                        },
                        collateralStatus: {
                            [u2]: {
                                loansTotalValue: toWei('0'), // not any debts
                                collateralsTotalValue: toWei('0.4')
                            }
                        }
                    }
                }
            }
        };

        await testFundingMatch(testConfig);
    });
});
