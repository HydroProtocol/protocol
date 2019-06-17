const TestToken = artifacts.require('./helper/TestToken.sol');
const BigNumber = require('bignumber.js');
const Hydro = artifacts.require('./Hydro.sol');

BigNumber.config({
    EXPONENTIAL_AT: 1000
});

module.exports = async () => {
    try {
        const hotToken = await TestToken.new('HOT', 'HOT', 18);
        console.log('HOT', hotToken.address);

        const tokenDAI = await TestToken.new('DAI', 'DAI', 18);
        console.log('DAI', tokenDAI.address);

        const tokenUSDC = await TestToken.new('USDC', 'USDC', 18);
        console.log('USDC', tokenUSDC.address);

        const tokenUSDT = await TestToken.new('USDT', 'USDT', 18);
        console.log('USDT', tokenUSDT.address);

        const hydro = await Hydro.new(hotToken.address);
        console.log('Hydro', hydro.address);

        await hydro.registerAsset(
            hotToken.address,
            '0xf000000000000000000000000000000000000000',
            'hotToken',
            'hotToken',
            18
        );
        await hydro.registerAsset(
            tokenDAI.address,
            '0xf000000000000000000000000000000000000000',
            'tokenDAI',
            'tokenDAI',
            18
        );
        await hydro.registerAsset(
            tokenUSDC.address,
            '0xf000000000000000000000000000000000000000',
            'tokenUSDC',
            'tokenUSDC',
            18
        );
        await hydro.registerAsset(
            tokenUSDT.address,
            '0xf000000000000000000000000000000000000000',
            'tokenUSDT',
            'tokenUSDT',
            18
        );

        await hydro.addMarket({
            liquidateRate: toWei('1'),
            withdrawRate: toWei('2'),
            baseAsset: hotToken.address,
            quoteAsset: tokenDAI.address,
            auctionRatioStart: '10000000000000000',
            auctionRatioPerBlock: '10000000000000000'
        });

        await hydro.addMarket({
            liquidateRate: toWei('1'),
            withdrawRate: toWei('2'),
            baseAsset: hotToken.address,
            quoteAsset: tokenUSDC.address,
            auctionRatioStart: '10000000000000000',
            auctionRatioPerBlock: '10000000000000000'
        });

        process.exit(0);
    } catch (e) {
        console.log(e);
    }
};
