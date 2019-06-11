const TestToken = artifacts.require('./helper/TestToken.sol');
const BigNumber = require('bignumber.js');
const Hydro = artifacts.require('./Hydro.sol');

BigNumber.config({ EXPONENTIAL_AT: 1000 });

module.exports = async () => {
    let token;

    try {
        const hotToken = await TestToken.new('HOT', 'HOT', 18);
        console.log('HOT', hotToken.address);

        token = await TestToken.new('DAI', 'DAI', 18);
        console.log('DAI', token.address);

        token = await TestToken.new('USDC', 'USDC', 18);
        console.log('USDC', token.address);

        token = await TestToken.new('USDT', 'USDT', 18);
        console.log('USDT', token.address);

        token = await Hydro.new(hotToken.address);
        console.log('Hydro', token.address);

        process.exit(0);
    } catch (e) {
        console.log(e);
    }
};
