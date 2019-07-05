require('../utils/hooks');
const assert = require('assert');
const { createAssets, newMarket } = require('../utils/assets');
const { toWei, logGas } = require('../utils');
const { supply, transfer, borrow } = require('../../sdk/sdk');
const { mineAt, getBlockTimestamp } = require('../utils/evm');
const Hydro = artifacts.require('./Hydro.sol');

contract('Insurance', accounts => {
    let hydro;
    let ETHAddr;
    let USDAddr;
    let MarketID;
    let initTime;
    let res;
    const u1 = accounts[4];
    const u2 = accounts[5];

    beforeEach(async () => {
        hydro = await Hydro.deployed();
        tokens = await createAssets([
            {
                symbol: 'ETH',
                oraclePrice: toWei('500'),
                collateralRate: 15000,
                decimals: 18,
                initBalances: {
                    [u2]: toWei('10')
                }
            },
            {
                name: 'USD',
                symbol: 'USD',
                oraclePrice: toWei('1'),
                collateralRate: 15000,
                decimals: 18,
                initBalances: {
                    [u1]: toWei('10000'),
                    [u2]: toWei('100')
                }
            }
        ]);
        ETHAddr = tokens[0].address;
        USDAddr = tokens[1].address;
        await newMarket({
            assets: [{ address: ETHAddr }, { address: USDAddr }]
        });
        MarketID = 0;

        await hydro.updateInsuranceRatio(toWei('0.1'));
        await hydro.updateMarket(MarketID, toWei('1'), toWei('0.01'), toWei('1.2'), toWei('2'));

        initTime = await getBlockTimestamp();
    });

    const addCollateral = async (user, asset, amount, timestamp) => {
        await mineAt(
            async () =>
                transfer(
                    asset,
                    {
                        category: 0,
                        marketID: 0,
                        user: user
                    },
                    {
                        category: 1,
                        marketID: 0,
                        user: user
                    },
                    amount,
                    {
                        from: user
                    }
                ),
            timestamp
        );
    };

    beforeEach(async () => {
        await mineAt(async () => supply(USDAddr, toWei('1000'), { from: u1 }), initTime);
        await addCollateral(u2, ETHAddr, toWei('1'), initTime);
        await mineAt(async () => borrow(0, USDAddr, toWei('100'), { from: u2 }), initTime);
    });

    it('check interest rate', async () => {
        interestRate = await hydro.getInterestRates(USDAddr, 0);
        assert.equal(interestRate[0].toString(), toWei(0.025)); // borrow interestRate 2.5%
        assert.equal(interestRate[1].toString(), toWei(0.00225)); // supply interestRate 0.225%
    });

    it('check insurance balance', async () => {
        await mineAt(async () => supply(USDAddr, '0', { from: u1 }), initTime + 86400 * 90);
        assert.equal((await hydro.getInsuranceBalance(USDAddr)).toString(), '61643835616438600');
    });
});
