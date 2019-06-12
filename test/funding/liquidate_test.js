require('../utils/hooks');
// const assert = require('assert');
const Hydro = artifacts.require('./Hydro.sol');
// const TestToken = artifacts.require('./helper/TestToken.sol');

const { newMarket } = require('../utils/assets');
const { toWei, pp, getUserKey } = require('../utils');
// const { buildOrder } = require('../utils/order');

contract('Liquidate', accounts => {
    let hydro;

    before(async () => {
        hydro = await Hydro.deployed();
    });

    const relayer = accounts[9];
    const u1 = accounts[4];
    const u2 = accounts[5];
    const u3 = accounts[6];

    it('should be a health position if there is no debt', async () => {
        assert.equal(await hydro.getAllMarketsCount(), '0');

        const { marketID } = await newMarket({
            liquidateRate: 120,
            withdrawRate: 200,
            assetConfigs: [
                {
                    symbol: 'ETH',
                    name: 'ETH',
                    decimals: 18,
                    oraclePrice: toWei('100'),
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
                    }
                }
            ],
            initMarketBalances: [
                {
                    [u1]: toWei('1')
                }
            ]
        });

        assert.equal(await hydro.getAllMarketsCount(), '1');

        const accountDetails = await hydro.getAccountDetails(u1, marketID);
        assert.equal(accountDetails.liquidable, false);
        assert.equal(accountDetails.debtsTotalUSDValue, '0');
        assert.equal(accountDetails.balancesTotalUSDValue, toWei('100'));
    });
});

//should be able to liquidate unhealthy account
