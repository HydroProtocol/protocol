require('../utils/hooks');

const { newMarket } = require('../utils/assets');
const { toWei, etherAsset, logGas } = require('../utils');
const Hydro = artifacts.require('./Hydro.sol');
const LendingPoolToken = artifacts.require('./LendingPoolToken.sol');
const DefaultInterestModel = artifacts.require('DefaultInterestModel.sol');
const assert = require('assert');

contract('Markets', accounts => {
    let hydro, defaultInterestModel, res;

    const fakePriceOracleAddress = '0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF';

    before(async () => {
        hydro = await Hydro.deployed();
        defaultInterestModel = await DefaultInterestModel.deployed();
    });

    it('should revert when try to get unexist asset', async () => {
        assert.rejects(
            hydro.getAsset('0x0000000000000000000000000000000000000000'),
            /ASSET_NOT_EXIST/
        );
    });

    it('can create asset', async () => {
        res = await hydro.createAsset(
            etherAsset,
            fakePriceOracleAddress,
            defaultInterestModel.address,
            'ETH',
            'ETH',
            18
        );

        logGas(res, 'hydro.createAsset');

        const asset = await hydro.getAsset(etherAsset);
        assert.equal(asset.priceOracle, fakePriceOracleAddress);

        const poolToken = await LendingPoolToken.at(asset.lendingPoolToken);
        assert.equal(hydro.address, await poolToken.owner());
    });

    it('can update asset', async () => {
        await hydro.createAsset(
            etherAsset,
            fakePriceOracleAddress,
            defaultInterestModel.address,
            'ETH',
            'ETH',
            18
        );

        const asset = await hydro.getAsset(etherAsset);
        assert.equal(asset.priceOracle, fakePriceOracleAddress);
        assert.equal(asset.interestModel, defaultInterestModel.address);

        const changedPriceOracleAddress = '0x1111111111111111111111111111111111111111';
        const changedInterestModelOracleAddress = '0x2222222222222222222222222222222222222222';

        res = await hydro.updateAsset(
            etherAsset,
            changedPriceOracleAddress,
            changedInterestModelOracleAddress
        );
        logGas(res, 'hydro.updateAsset');

        const asset2 = await hydro.getAsset(etherAsset);
        assert.equal(asset2.priceOracle, changedPriceOracleAddress);
        assert.equal(asset2.interestModel, changedInterestModelOracleAddress);
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
        assert.equal((await hydro.getAssetOraclePrice(baseAsset.address)).toString(), toWei('100'));
        assert.equal((await hydro.getAssetOraclePrice(quoteAsset.address)).toString(), toWei('1'));
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
        await hydro.createAsset(
            etherAsset,
            fakePriceOracleAddress,
            defaultInterestModel.address,
            'ETH',
            'ETH',
            18
        );

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
        await hydro.createAsset(
            etherAsset,
            fakePriceOracleAddress,
            defaultInterestModel.address,
            'ETH',
            'ETH',
            18
        );

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
