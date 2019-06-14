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
        const { baseAsset, quoteAsset } = await newMarket({
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

        const market = await hydro.getMarket(0);
        assert.equal(market.baseAsset, baseAsset.address);
        assert.equal(market.quoteAsset, quoteAsset.address);
    });

    it('can not add invalid market, same quote and base', async () => {
        assert.rejects(
            newMarket({
                assets: [{ address: etherAsset }, { address: etherAsset }]
            }),
            /BASE_QUOTE_DUPLICATED/
        );
    });

    it('can not add invalid market, unregistered base asset', async () => {
        // register fake ether asset oracle
        await hydro.registerAsset(etherAsset, fakeOracleAddress, 'ETH', 'ETH', 18);

        await assert.rejects(
            newMarket({
                assets: [
                    { address: '0xffffffffffffffffffffffffffffffffffffffff' },
                    { address: etherAsset }
                ]
            }),
            /MARKET_BASE_ASSET_NOT_EXIST/
        );
    });

    it('can not add invalid market, unregistered quote asset', async () => {
        // register fake ether asset oracle
        await hydro.registerAsset(etherAsset, fakeOracleAddress, 'ETH', 'ETH', 18);

        await assert.rejects(
            newMarket({
                assets: [
                    { address: etherAsset },
                    { address: '0xffffffffffffffffffffffffffffffffffffffff' }
                ]
            }),
            /MARKET_QUOTE_ASSET_NOT_EXIST/
        );
    });

    it('can not add duplicated market', async () => {
        await assert.rejects(async () => {
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

            await newMarket({ assets: [assets.baseAsset, assets.quoteAsset] });
        }, /MARKET_ALREADY_EXIST/);

        assert.equal(await hydro.getAllMarketsCount.call(), 1);
    });
});
