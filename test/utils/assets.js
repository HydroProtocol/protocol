const debug = require('debug')('hydro:Asset');
const { newContract } = require('./index.js');
const Oracle = artifacts.require('./Oracle.sol');
const Hydro = artifacts.require('./Hydro.sol');
const TestToken = artifacts.require('./helpers/TestToken.sol');

const BigNumber = require('bignumber.js');
BigNumber.config({ EXPONENTIAL_AT: 1000 });

const getLastAsset = async () => {
    const hydro = await Hydro.deployed();
    const assetCount = await hydro.getAllAssetsCount();
    return hydro.getAsset(assetCount.toNumber() - 1);
};

const depositAsset = async (token, user, amount) => {
    const hydro = await Hydro.deployed();
    const assetID = await hydro.getAssetIDByAddress(token.address);
    const accounts = await web3.eth.getAccounts();
    const owner = accounts[0];

    if (token.symbol == 'ETH') {
        await hydro.deposit(assetID, amount, { from: user, value: amount });
    } else {
        await token.transfer(user, amount, { from: owner });
        await token.approve(hydro.address, amount, { from: user });
        await hydro.deposit(assetID, amount, { from: user });
    }
};

const depositCollateral = async (token, user, amount) => {
    const hydro = await Hydro.deployed();
    const assetID = await hydro.getAssetIDByAddress(token.address);
    await hydro.depositCollateral(assetID, amount, { from: user });
};

const depositPool = async (token, user, amount) => {
    const hydro = await Hydro.deployed();
    const assetID = await hydro.getAssetIDByAddress(token.address);
    await hydro.poolSupply(assetID, amount, { from: user });
};

const createAsset = async assetConfig => {
    const hydro = await Hydro.deployed();
    const accounts = await web3.eth.getAccounts();
    const owner = accounts[0];

    const { initBalances, initCollaterals, oraclePrice, initPool } = assetConfig;

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

    // set oracle price
    if (oraclePrice) {
        await oracle.setPrice(token.address, new BigNumber(oraclePrice).toString(), {
            from: accounts[0]
        });
    }

    debug(
        `Token ${token.symbol} price is ${(token.address, await oracle.getPrice(token.address))}`
    );

    await hydro.addAsset(token.address, 1, oracle.address, {
        from: accounts[0],
        gasLimit: 10000000
    });

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
            await depositCollateral(token, user, amount);
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

    debug(`Create Asset ${token.symbol} done`);

    return token;
};

const createAssets = async configs => {
    const tokens = await Promise.all(configs.map(config => createAsset(config)));

    tokens.forEach((t, i) => (t.symbol = configs[i]));

    return tokens;
};

module.exports = {
    createAssets,
    createAsset
};
