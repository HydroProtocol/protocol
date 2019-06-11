const Oracle = artifacts.require('./Oracle.sol');
const HydroToken = artifacts.require('./HydroToken.sol');
const BigNumber = require('bignumber.js');

BigNumber.config({
    EXPONENTIAL_AT: 1000
});

const wei = new BigNumber('1000000000000000000');

const toWei = x => {
    return new BigNumber(x).times(wei).toString();
};

const newContract = async (contract, ...args) => {
    const c = await contracπpoot.new(...args);
    const instance = new web3.eth.Contract(contract.abi, c.address);
    return instance;
};

const newContractAt = (contract, address) => {
    const instance = new web3.eth.Contract(contract.abi, address);
    return instance;
};

const setHotAmount = async (user, amount) => {
    const hot = await HydroToken.deployed();
    const balance = await hot.balanceOf(user);
    const accounts = await web3.eth.getAccounts();
    const diff = new BigNumber(amount).minus(balance);

    if (diff.gt(0)) {
        await hot.transfer(user, diff.toString(), { from: accounts[0] });
    } else if (diff.lt(0)) {
        await hot.transfer(accounts[0], diff.abs().toString(), { from: user });
    }
};

const clone = x => JSON.parse(JSON.stringify(x));

const pp = obj => {
    console.log(JSON.stringify(obj, null, 2));
};

const getUserKey = u => {
    const accounts = web3.eth.getAccounts();
    const relayer = accounts[9];
    const u1 = accounts[4];
    const u2 = accounts[5];
    const u3 = accounts[6];
    const u4 = accounts[7];
    const u5 = accounts[8];

    switch (u) {
        case u1:
            return 'u1';
        case u2:
            return 'u2';
        case u3:
            return 'u3';
        case u4:
            return 'u4';
        case u5:
            return 'u5';
        case relayer:
            return 'relayer';
    }
};

module.exports = {
    newContract,
    newContractAt,
    clone,
    setHotAmount,
    toWei,
    getUserKey,
    wei,
    pp
};
