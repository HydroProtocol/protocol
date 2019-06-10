require('../utils/hooks');

const { newMarket } = require('../utils/assets');
const { toWei } = require('../utils');
const Hydro = artifacts.require('./Hydro.sol');
const assert = require('assert');

contract('Markets', accounts => {
    let hydro;

    before(async () => {
        hydro = await Hydro.deployed();
    });

    it('no markets at first', async () => {
        assert.equal(await hydro.getAllMarketsCount.call(), 0);
    });

    it('owner can add market', async () => {
        await newMarket({
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
                    oraclePrice: toWei('1')
                }
            ]
        });
    });

    it('can not add duplicated market', async () => {
        try {
            const assets = await newMarket({
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
                        oraclePrice: toWei('1')
                    }
                ]
            });

            await newMarket({ assets: [assets.baseToken, assets.quoteToken] });
        } catch (e) {
            assert.equal(await hydro.getAllMarketsCount.call(), 1);
            assert.ok(e.message.match(/MARKET_IS_ALREADY_EXIST/));
            return;
        }

        asset(false, 'Should never get here');
    });
});
