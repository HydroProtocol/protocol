const Proxy = artifacts.require('./Proxy.sol');
const HybridExchange = artifacts.require('./HybridExchange.sol');
const TestToken = artifacts.require('./helper/TestToken.sol');
const BigNumber = require('bignumber.js');

BigNumber.config({ EXPONENTIAL_AT: 1000 });

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
        await hotContract.methods.transfer(user, diff.toString()).send({ from: accounts[0] });
    } else if (diff.lt(0)) {
        await hotContract.methods.transfer(accounts[0], diff.abs().toString()).send({ from: user });
    }
};

const getContracts = async () => {
    const accounts = await web3.eth.getAccounts();
    const proxy = await newContract(Proxy);
    // console.log('Proxy address', web3.utils.toChecksumAddress(proxy._address));

    const hot = await newContract(TestToken, 'HydroToken', 'Hot', 18);
    // console.log('Hydro Token address', web3.utils.toChecksumAddress(hot._address));

    const exchange = await newContract(HybridExchange, proxy._address, hot._address);
    // console.log('Dxchange address', web3.utils.toChecksumAddress(exchange._address));

    await proxy.methods.addAddress(exchange._address).send({ from: accounts[0] });

    return {
        hot,
        proxy,
        exchange
    };
};

const clone = x => JSON.parse(JSON.stringify(x));

module.exports = {
    newContract,
    newContractAt,
    getContracts,
    clone,
    setHotAmount
};
