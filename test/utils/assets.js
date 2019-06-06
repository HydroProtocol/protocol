const debug = require('debug')('hydro:Asset');
const Oracle = artifacts.require('./Oracle.sol');
const Hydro = artifacts.require('./Hydro.sol');
const TestToken = artifacts.require('./helpers/TestToken.sol');
const BigNumber = require('bignumber.js');

BigNumber.config({
    EXPONENTIAL_AT: 1000
});

const newMarket = async marketConfig => {
    const { assets, assetConfigs, liquidateRate, withdrawRate } = marketConfig;
    let baseToken, quoteToken;

    if (assetConfigs) {
        [baseToken, quoteToken] = await createAssets(assetConfigs);
    } else if (assets) {
        [baseToken, quoteToken] = assets;
    }

    const hydro = await Hydro.deployed();

    const res = await hydro.addMarket({
        liquidateRate: liquidateRate || 120,
        withdrawRate: withdrawRate || 200,
        baseAsset: baseToken.address,
        quoteAsset: quoteToken.address
    });

    debug('add market gas cost:', res.receipt.gasUsed);

    return {
        baseToken,
        quoteToken
    };
};

const depositAsset = async (token, user, amount) => {
    const hydro = await Hydro.deployed();
    const accounts = await web3.eth.getAccounts();
    const owner = accounts[0];

    if (token.symbol == 'ETH') {
        await hydro.deposit(token.address, amount, {
            from: user,
            value: amount
        });
    } else {
        await token.transfer(user, amount, {
            from: owner
        });
        await token.approve(hydro.address, amount, {
            from: user
        });
        await hydro.deposit(token.address, amount, {
            from: user
        });
    }
};

const depositDefaultCollateral = async (token, user, amount) => {
    const hydro = await Hydro.deployed();
    await hydro.depositDefaultCollateral(token.address, amount, {
        from: user
    });
};

const depositPool = async (token, user, amount) => {
    const hydro = await Hydro.deployed();
    await hydro.poolSupply(token.address, amount, {
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
        oracle.setPrice(token.address, new BigNumber(oraclePrice || 10000).toString(), {
            from: accounts[0]
        }),
        hydro.registerOracle(token.address, oracle.address)
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

    if (initCollaterals) {
        for (let j = 0; j < Object.keys(initCollaterals).length; j++) {
            const user = Object.keys(initCollaterals)[j];
            const amount = initCollaterals[user];
            await depositAsset(token, user, amount);
            await depositDefaultCollateral(token, user, amount);
        }
    }

    if (initPool) {
        for (let j = 0; j < Object.keys(initPool).length; j++) {
            const user = Object.keys(initPool)[j];
            const amount = initPool[user];
            await depositAsset(token, user, amount);
            await depositPool(token, user, amount);
        }
    }

    return token;
};

const createAssets = async configs => {
    const tokens = await Promise.all(configs.map(config => createAsset(config)));

    tokens.forEach((t, i) => (t.symbol = configs[i]));

    return tokens;
};

module.exports = {
    createAssets,
    createAsset,
    depositPool,
    newMarket
};
