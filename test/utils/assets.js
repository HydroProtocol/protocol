const debug = require('debug')('hydro:Asset');
const Oracle = artifacts.require('./Oracle.sol');
const Hydro = artifacts.require('./Hydro.sol');
const TestToken = artifacts.require('./helpers/TestToken.sol');
const BigNumber = require('bignumber.js');
const { toWei } = require('./index');

BigNumber.config({
    EXPONENTIAL_AT: 1000
});

const depositAsset = async (asset, user, amount) => {
    const hydro = await Hydro.deployed();
    const accounts = await web3.eth.getAccounts();
    const owner = accounts[0];

    if (asset.symbol == 'ETH') {
        await hydro.deposit(asset.address, amount, {
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
        await hydro.deposit(asset.address, amount, {
            from: user
        });
    }
};

const depositMarket = async (marketID, asset, user, amount) => {
    const hydro = await Hydro.deployed();
    await depositAsset(asset, user, amount);
    await hydro.transfer(
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

    const res = await hydro.addMarket({
        liquidateRate: liquidateRate || 120,
        withdrawRate: withdrawRate || 200,
        baseAsset: baseAsset.address,
        quoteAsset: quoteAsset.address,
        auctionRatioStart: toWei('0.01'),
        auctionRatioPerBlock: toWei('0.01')
    });

    const marketID = (await hydro.getAllMarketsCount()).toNumber() - 1;

    debug(`new Market ${baseAsset.symbol}-${quoteAsset.symbol}, marketID: ${marketID}`);
    debug('add market gas cost:', res.receipt.gasUsed);

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

const deposit = async (token, user, amount) => {
    const hydro = await Hydro.deployed();
    await hydro.deposit(token.address, amount, {
        from: user
    });
};

const supply = async (token, user, amount) => {
    const hydro = await Hydro.deployed();
    await hydro.supplyPool(token.address, amount, {
        from: user
    });
};

const createAsset = async assetConfig => {
    const accounts = await web3.eth.getAccounts();
    const hydro = await Hydro.deployed();
    const owner = accounts[0];

    const { initBalances, initCollaterals, initPool, oraclePrice } = assetConfig;

    let token;

    // prepare token contract
    if (assetConfig.symbol == 'ETH') {
        token = {
            address: '0x0000000000000000000000000000000000000000',
            symbol: 'ETH'
        };
    } else {
        token = await TestToken.new(assetConfig.name, assetConfig.symbol, assetConfig.decimals, {
            from: owner
        });

        token.symbol = assetConfig.symbol;
    }

    const oracle = await Oracle.deployed();

    await Promise.all([
        oracle.setPrice(token.address, oraclePrice || toWei(100), {
            from: accounts[0]
        }),

        hydro.registerAsset(
            token.address,
            oracle.address,
            'supply shares ' + assetConfig.name,
            'S' + assetConfig.symbol,
            assetConfig.decimals
        )
    ]);

    debug(
        `Token ${token.symbol} price is ${(token.address, await oracle.getPrice(token.address))}`
    );

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

    // if (initPool) {
    //     for (let j = 0; j < Object.keys(initPool).length; j++) {
    //         const user = Object.keys(initPool)[j];
    //         const amount = initPool[user];
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
    supply,
    newMarket
};
