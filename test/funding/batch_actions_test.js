require('../utils/hooks');

const assert = require('assert');
const Hydro = artifacts.require('./Hydro.sol');
const Ethers = require('ethers');
const { toWei, logGas } = require('../utils');
const { newMarket } = require('../utils/assets');
const { deposit } = require('../../sdk/sdk');

const encoder = new Ethers.utils.AbiCoder();

contract('Batch', accounts => {
    let hydro;

    const ActionType = {
        Deposit: 0,
        Withdraw: 1,
        Transfer: 2,
        Borrow: 3,
        Repay: 4,
        Supply: 5,
        Unsupply: 6
    };

    const ethAddress = '0x000000000000000000000000000000000000000E';
    const u1 = accounts[0];
    const u2 = accounts[1];

    const createMarket = () => {
        return newMarket({
            assetConfigs: [
                {
                    symbol: 'ETH',
                    name: 'ETH',
                    decimals: 18,
                    oraclePrice: toWei('100')
                },
                {
                    symbol: 'USD',
                    name: 'USD',
                    decimals: 18,
                    oraclePrice: toWei('1'),
                    initBalances: {
                        [u2]: toWei('1000')
                    }
                }
            ]
        });
    };

    before(async () => {
        hydro = await Hydro.deployed();
    });

    it('deposit', async () => {
        const balanceBefore = await hydro.balanceOf(ethAddress, u1);
        const actions = [
            {
                actionType: ActionType.Deposit,
                encodedParams: encoder.encode(['address', 'uint256'], [ethAddress, toWei('1')])
            }
        ];

        const res = await hydro.batch(actions, { value: toWei('1') });

        logGas(res, 'deposit(batch)');

        const balanceAfter = await hydro.balanceOf(ethAddress, u1);

        assert.equal(balanceAfter.sub(balanceBefore).toString(), toWei('1'));
    });

    it('withdraw', async () => {
        // prepare
        await deposit(ethAddress, toWei('1'), { value: toWei('1') });
        const balanceBefore = await hydro.balanceOf(ethAddress, u1);
        assert.equal(balanceBefore.toString(), toWei('1'));

        // test
        const actions = [
            {
                actionType: ActionType.Withdraw,
                encodedParams: encoder.encode(['address', 'uint256'], [ethAddress, toWei('1')])
            }
        ];

        const res = await hydro.batch(actions);
        logGas(res, 'withdraw(batch)');
        const balanceAfter = await hydro.balanceOf(ethAddress, u1);

        assert.equal(balanceAfter.toString(), toWei('0'));
    });

    it('transfer', async () => {
        // prepare
        await createMarket();

        await deposit(ethAddress, toWei('1'), { value: toWei('1') });
        const balanceBefore = await hydro.balanceOf(ethAddress, u1);
        assert.equal(balanceBefore.toString(), toWei('1'));

        const marketBalanceBefore = await hydro.marketBalanceOf(0, ethAddress, u1);
        assert.equal(marketBalanceBefore.toString(), toWei('0'));

        // test
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
                    [ethAddress, [0, 0, u1], [1, 0, u1], toWei('1')]
                )
            }
        ];

        const res = await hydro.batch(actions);
        logGas(res, 'transfer(batch)');
        const balanceAfter = await hydro.balanceOf(ethAddress, u1);
        assert.equal(balanceAfter.toString(), toWei('0'));

        const marketBalanceAfter = await hydro.marketBalanceOf(0, ethAddress, u1);
        assert.equal(marketBalanceAfter.toString(), toWei('1'));
    });

    it('supply and unsupply', async () => {
        await createMarket();
        const actions = [
            {
                actionType: ActionType.Deposit,
                encodedParams: encoder.encode(['address', 'uint256'], [ethAddress, toWei('1')])
            },
            {
                actionType: ActionType.Supply,
                encodedParams: encoder.encode(['address', 'uint256'], [ethAddress, toWei('1')])
            },
            {
                actionType: ActionType.Unsupply,
                encodedParams: encoder.encode(['address', 'uint256'], [ethAddress, toWei('1')])
            }
        ];
        const res = await hydro.batch(actions, { value: toWei('1') });
        logGas(res, 'supply + unsupply(batch)');
    });

    it('borrow and repay', async () => {
        // u1 supply pool
        // u2 borrow and repay
        let res = await createMarket();

        usdAddress = res.quoteAsset.address;
        marketID = res.marketID;
        const u1Actions = [
            {
                actionType: ActionType.Deposit,
                encodedParams: encoder.encode(['address', 'uint256'], [ethAddress, toWei('1')])
            },
            {
                actionType: ActionType.Supply,
                encodedParams: encoder.encode(['address', 'uint256'], [ethAddress, toWei('1')])
            }
        ];
        res = await hydro.batch(u1Actions, { from: u1, value: toWei('1') });
        logGas(res, 'deposit + supply (batch)');
        const u2Actions = [
            {
                actionType: ActionType.Transfer,
                encodedParams: encoder.encode(
                    [
                        'address',
                        'tuple(uint8,uint16,address)',
                        'tuple(uint8,uint16,address)',
                        'uint256'
                    ],
                    [usdAddress, [0, marketID, u2], [1, marketID, u2], toWei('1000')]
                )
            },
            {
                actionType: ActionType.Borrow,
                encodedParams: encoder.encode(
                    ['uint16', 'address', 'uint256'],
                    [marketID, ethAddress, toWei('1')]
                )
            },
            {
                actionType: ActionType.Repay,
                encodedParams: encoder.encode(
                    ['uint16', 'address', 'uint256'],
                    [marketID, ethAddress, toWei('1')]
                )
            }
        ];
        res = await hydro.batch(u2Actions, { from: u2 });
        logGas(res, 'transfer + borrow + repay (batch)');
    });
});
