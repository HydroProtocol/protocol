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

let hotTokenAddress = null;
let proxyAddress = null;
let exchangeAddress = null;

module.exports = async () => {
    let hot, exchange, proxy;
    try {
        if (!hotTokenAddress) {
            hot = await newContract(TestToken, 'HydroToken', 'Hot', 18);
            hotTokenAddress = hot._address;
        } else {
            hot = await newContractAt(TestToken, hotTokenAddress);
        }
        console.log('Hydro Token address', web3.toChecksumAddress(hotTokenAddress));

        if (!proxyAddress) {
            proxy = await newContract(Proxy);
            proxyAddress = proxy._address;
        } else {
            proxy = await newContractAt(Proxy, proxyAddress);
        }
        console.log('Proxy address', web3.toChecksumAddress(proxyAddress));

        if (!exchangeAddress) {
            exchange = await newContract(HybridExchange, proxyAddress, hotTokenAddress);
            exchangeAddress = exchange._address;
        } else {
            exchange = await newContractAt(HybridExchange, exchangeAddress);
        }
        console.log('HybridExchange address', web3.toChecksumAddress(exchangeAddress));

        await Proxy.at(proxyAddress).addAddress(exchangeAddress);
        console.log('Proxy add exchange into whitelist');

        process.exit(0);
    } catch (e) {
        console.log(e);
    }
};
