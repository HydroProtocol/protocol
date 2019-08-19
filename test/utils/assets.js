const PriceOracle = artifacts.require('./helper/PriceOracle.sol');
const Hydro = artifacts.require('./Hydro.sol');
const DefaultInterestModel = artifacts.require('DefaultInterestModel.sol');
const TestToken = artifacts.require('./helpers/TestToken.sol');
const BigNumber = require('bignumber.js');
const { toWei, logGas } = require('./index');
const { deposit, transfer } = require('../../sdk/sdk');

BigNumber.config({
    EXPONENTIAL_AT: 1000
});

const depositAsset = async (asset, user, amount) => {
    const hydro = await Hydro.deployed();
    const accounts = await web3.eth.getAccounts();
    const owner = accounts[0];

    if (asset.symbol == 'ETH') {
        await deposit(asset.address, amount, {
            from: user,
            value: amount
        });
    } else {
        await asset.transfer(user, amount, {
            from: owner
        });
        await asset.approve(hydro.address, amount, {
            from: user
        });
        await deposit(asset.address, amount, {
            from: user
        });
    }
};

const depositMarket = async (marketID, asset, user, amount) => {
    const hydro = await Hydro.deployed();
    await depositAsset(asset, user, amount);
    await transfer(
        asset.address,
        {
            category: 0,
            marketID,
            user
        },
        {
            category: 1,
            marketID,
            user
        },
        amount,
        { from: user }
    );
};

const newMarket = async marketConfig => {
    const { assets, assetConfigs, liquidateRate, withdrawRate, initMarketBalances } = marketConfig;
    let baseAsset, quoteAsset;

    if (assetConfigs) {
        [baseAsset, quoteAsset] = await createAssets(assetConfigs);
    } else if (assets) {
        [baseAsset, quoteAsset] = assets;
    }

    const hydro = await Hydro.deployed();

    await hydro.createMarket({
        liquidateRate: liquidateRate || toWei('1.2'),
        withdrawRate: withdrawRate || toWei('2'),
        baseAsset: baseAsset.address,
        quoteAsset: quoteAsset.address,
        auctionRatioStart: toWei('0.01'),
        auctionRatioPerBlock: toWei('0.01'),
        borrowEnable: true
    });

    const marketID = (await hydro.getAllMarketsCount()).toNumber() - 1;

    // logGas(res, 'new market');

    if (initMarketBalances) {
        if (initMarketBalances[0]) {
            const users = Object.keys(initMarketBalances[0]);
            for (let i = 0; i < users.length; i++) {
                const user = users[i];
                const amount = initMarketBalances[0][user];
                await depositMarket(marketID, baseAsset, user, amount);
            }
        }

        if (initMarketBalances[1]) {
            const users = Object.keys(initMarketBalances[1]);
            for (let i = 0; i < users.length; i++) {
                const user = users[i];
                const amount = initMarketBalances[1][user];
                await depositMarket(marketID, quoteAsset, user, amount);
            }
        }
    }

    return {
        baseAsset,
        quoteAsset,
        marketID
    };
};

const createAsset = async assetConfig => {
    const accounts = await web3.eth.getAccounts();
    const hydro = await Hydro.deployed();
    const defaultInterestModel = await DefaultInterestModel.deployed();
    const owner = accounts[0];

    const { initBalances, initCollaterals, initLendingPool, oraclePrice } = assetConfig;

    let token;

    // prepare token contract
    if (assetConfig.symbol == 'ETH') {
        token = {
            address: '0x000000000000000000000000000000000000000E',
            symbol: 'ETH'
        };
    } else {
        token = await TestToken.new(assetConfig.name, assetConfig.symbol, assetConfig.decimals, {
            from: owner
        });

        token.symbol = assetConfig.symbol;
    }

    const oracle = await PriceOracle.deployed();
    let res = await oracle.setPrice(token.address, oraclePrice || toWei(100), {
        from: accounts[0]
    });

    // logGas(res, 'oracle setPrice');

    res = await hydro.createAsset(
        token.address,
        oracle.address,
        defaultInterestModel.address,
        'supply shares ' + assetConfig.name,
        'S' + assetConfig.symbol,
        assetConfig.decimals
    );

    // logGas(res, 'createAsset');

    if (initBalances) {
        for (let j = 0; j < Object.keys(initBalances).length; j++) {
            const user = Object.keys(initBalances)[j];
            const amount = initBalances[user];
            await depositAsset(token, user, amount);
        }
    }

    // if (initCollaterals) {
    //     for (let j = 0; j < Object.keys(initCollaterals).length; j++) {
    //         const user = Object.keys(initCollaterals)[j];
    //         const amount = initCollaterals[user];
    //         await depositAsset(token, user, amount);
    //         await deposit(token, user, amount);
    //     }
    // }

    // if (initLendingPool) {
    //     for (let j = 0; j < Object.keys(initLendingPool).length; j++) {
    //         const user = Object.keys(initLendingPool)[j];
    //         const amount = initLendingPool[user];
    //         await depositAsset(token, user, amount);
    //         await supply(token, user, amount);
    //     }
    // }

    return token;
};

const createAssets = async configs => {
    const tokens = await Promise.all(configs.map(config => createAsset(config)));

    tokens.forEach((t, i) => (t.symbol = configs[i].symbol));

    return tokens;
};

module.exports = {
    createAssets,
    createAsset,
    depositMarket,
    newMarket
};
