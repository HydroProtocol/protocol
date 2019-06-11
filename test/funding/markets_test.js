require('../utils/hooks');

const { newMarket } = require('../utils/assets');
const { toWei, etherAsset } = require('../utils');
const Hydro = artifacts.require('./Hydro.sol');
const assert = require('assert');

contract('Markets', accounts => {
    let hydro;

    const fakeOracleAddress = '0xffffffffffffffffffffffffffffffffffffffff';

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

    it('can not add invalid market, same quote and base', async () => {
        try {
            await newMarket({
                assets: [{ address: etherAsset }, { address: etherAsset }]
            });
        } catch (e) {
            assert.ok(e.message.match(/BASE_QUOTE_DUPLICATED/));
            return;
        }

        asset(false, 'Should never get here');
    });

    it('can not add invalid market, unregistered base asset', async () => {
        // register fake ether asset oracle
        await hydro.registerAsset(etherAsset, fakeOracleAddress, 'ETH', 'ETH', 18);

        try {
            await newMarket({
                assets: [
                    { address: '0xffffffffffffffffffffffffffffffffffffffff' },
                    { address: etherAsset }
                ]
            });
        } catch (e) {
            assert.ok(e.message.match(/MARKET_BASE_ASSET_NOT_EXIST/));
            return;
        }

        asset(false, 'Should never get here');
    });

    it('can not add invalid market, unregistered quote asset', async () => {
        // register fake ether asset oracle
        await hydro.registerAsset(etherAsset, fakeOracleAddress, 'ETH', 'ETH', 18);

        try {
            await newMarket({
                assets: [
                    { address: etherAsset },
                    { address: '0xffffffffffffffffffffffffffffffffffffffff' }
                ]
            });
        } catch (e) {
            assert.ok(e.message.match(/MARKET_QUOTE_ASSET_NOT_EXIST/));
            return;
        }

        asset(false, 'Should never get here');
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
            assert.ok(e.message.match(/MARKET_ALREADY_EXIST/));
            return;
        }

        asset(false, 'Should never get here');
    });
});
