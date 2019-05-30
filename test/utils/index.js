const Oracle = artifacts.require('./Oracle.sol');
const Hydro = artifacts.require('./Hydro.sol');
const HybridExchange = artifacts.require('./HybridExchange.sol');
const TestToken = artifacts.require('./helper/TestToken.sol');
const Funding = artifacts.require('./Funding.sol');
const BigNumber = require('bignumber.js');

BigNumber.config({
    EXPONENTIAL_AT: 1000
});

const weis = new BigNumber('1000000000000000000');

const toWei = x => {
    return new BigNumber(x).times(weis).toString();
};

const newContract = async (contract, ...args) => {
    const c = await contract.new(...args);
    const instance = new web3.eth.Contract(contract.abi, c.address);
    return instance;
};

const newContractAt = (contract, address) => {
    const instance = new web3.eth.Contract(contract.abi, address);
    return instance;
};

const setHotAmount = async (hotContract, user, amount) => {
    const balance = await hotContract.methods.balanceOf(user).call();
    const accounts = await web3.eth.getAccounts();
    const diff = new BigNumber(amount).minus(balance);

    if (diff.gt(0)) {
        await hotContract.methods.transfer(user, diff.toString()).send({
            from: accounts[0]
        });
    } else if (diff.lt(0)) {
        await hotContract.methods.transfer(accounts[0], diff.abs().toString()).send({
            from: user
        });
    }
};

const setTokenAmount = async (toeknContract, user, amount) => {
    const balance = await toeknContract.methods.balanceOf(user).call();
    const accounts = await web3.eth.getAccounts();
    const diff = new BigNumber(amount).minus(balance);

    if (diff.gt(0)) {
        await toeknContract.methods.transfer(user, diff.toString()).send({
            from: accounts[0]
        });
    } else if (diff.lt(0)) {
        await toeknContract.methods.transfer(accounts[0], diff.abs().toString()).send({
            from: user
        });
    }
};

const getExchangeContracts = async () => {
    const accounts = await web3.eth.getAccounts();
    const proxy = await newContract(Proxy);
    // console.log('Proxy address', web3.utils.toChecksumAddress(proxy._address));

    const hot = await newContract(TestToken, 'HydroToken', 'Hot', 18);
    // console.log('Hydro Token address', web3.utils.toChecksumAddress(hot._address));

    const exchange = await newContract(HybridExchange, proxy._address, hot._address);
    // console.log('Dxchange address', web3.utils.toChecksumAddress(exchange._address));

    await proxy.methods.addAddress(exchange._address).send({
        from: accounts[0]
    });

    return {
        hot,
        proxy,
        exchange
    };
};

const getHydroContract = async () => {
    const hydro = await newContract(Hydro);
    console.log('Hydro address', web3.utils.toChecksumAddress(hydro._address));
    return hydro;
};

const clone = x => JSON.parse(JSON.stringify(x));

module.exports = {
    newContract,
    newContractAt,
    getContracts: getExchangeContracts,
    getFundingContracts,
    clone,
    setHotAmount,
    toWei
};