const Web3 = require('web3');
const Proxy = artifacts.require('./Proxy.sol');
const HybridExchange = artifacts.require('./HybridExchange.sol');
const TestToken = artifacts.require('./helper/TestToken.sol');
const BigNumber = require('bignumber.js');

BigNumber.config({ EXPONENTIAL_AT: 1000 });

const getWeb3 = () => {
    const myWeb3 = new Web3(web3.currentProvider);
    return myWeb3;
};

const newContract = async (contract, ...args) => {
    const c = await contract.new(...args);
    const w = getWeb3();
    const instance = new w.eth.Contract(contract.abi, c.address);
    return instance;
};

const newContractAt = (contract, address) => {
    const w = getWeb3();
    const instance = new w.eth.Contract(contract.abi, address);
    return instance;
};

const setHotAmount = async (hotContract, user, amount) => {
    const balance = await hotContract.methods.balanceOf(user).call();

    const diff = new BigNumber(amount).minus(balance);

    if (diff.gt(0)) {
        await hotContract.methods.transfer(user, diff.toString()).send({ from: web3.eth.accounts[0] });
    } else if (diff.lt(0)) {
        await hotContract.methods.transfer(web3.eth.accounts[0], diff.abs().toString()).send({ from: user });
    }
};

const getContracts = async () => {
    const proxy = await newContract(Proxy);
    // console.log('Proxy address', web3.toChecksumAddress(proxy._address));

    const hot = await newContract(TestToken, 'HydroToken', 'Hot', 18);
    // console.log('Hydro Token address', web3.toChecksumAddress(hot._address));

    const exchange = await newContract(HybridExchange, proxy._address, hot._address);
    // console.log('Dxchange address', web3.toChecksumAddress(exchange._address));

    await proxy.methods.addAddress(exchange._address).send({ from: web3.eth.coinbase });

    return {
        hot,
        proxy,
        exchange
    };
};

const clone = x => JSON.parse(JSON.stringify(x));

module.exports = {
    getWeb3,
    newContract,
    newContractAt,
    getContracts,
    clone,
    setHotAmount
};
