require('../utils/hooks');
const assert = require('assert');
const Hydro = artifacts.require('./Hydro.sol');
const Ethers = require('ethers');
const { toWei } = require('../utils');
const { newMarket } = require('../utils/assets');

const encoder = new Ethers.utils.AbiCoder();

contract('Batch', accounts => {
    let hydro;

    const etherAsset = '0x0000000000000000000000000000000000000000';
    const user = accounts[0];

    const createMarket = () => {
        return newMarket({
            assetConfigs: [
                {
                    symbol: 'ETH',
                    name: 'ETH',
                    decimals: 18,
                    oraclePrice: toWei('100')
                },
                {
                    symbol: 'USD',
                    name: 'USD',
                    decimals: 18,
                    oraclePrice: toWei('1')
                }
            ]
        });
    };

    before(async () => {
        hydro = await Hydro.deployed();
    });

    it('deposit', async () => {
        const balanceBefore = await hydro.balanceOf(etherAsset, user);

        await hydro.deposit(etherAsset, toWei('1'), { value: toWei('1') });
        const balanceAfter = await hydro.balanceOf(etherAsset, user);

        assert.equal(balanceAfter.sub(balanceBefore).toString(), toWei('1'));
    });

    it('withdraw', async () => {
        // prepare
        await hydro.deposit(etherAsset, toWei('1'), { value: toWei('1') });
        const balanceBefore = await hydro.balanceOf(etherAsset, user);
        assert.equal(balanceBefore.toString(), toWei('1'));

        // test
        await hydro.withdraw(etherAsset, toWei('1'));
        const balanceAfter = await hydro.balanceOf(etherAsset, user);

        assert.equal(balanceAfter.toString(), toWei('0'));
    });

    it('transfer', async () => {
        // prepare
        await createMarket();

        await hydro.deposit(etherAsset, toWei('1'), { value: toWei('1') });
        const balanceBefore = await hydro.balanceOf(etherAsset, user);
        assert.equal(balanceBefore.toString(), toWei('1'));

        const marketBalanceBefore = await hydro.marketBalanceOf(0, etherAsset, user);
        assert.equal(marketBalanceBefore.toString(), toWei('0'));

        // test
        await hydro.transfer(
            etherAsset,
            {
                category: 0,
                marketID: 0,
                user: user
            },
            {
                category: 1,
                marketID: 0,
                user: user
            },
            toWei('1')
        );

        const balanceAfter = await hydro.balanceOf(etherAsset, user);
        assert.equal(balanceAfter.toString(), toWei('0'));

        const marketBalanceAfter = await hydro.marketBalanceOf(0, etherAsset, user);
        assert.equal(marketBalanceAfter.toString(), toWei('1'));
    });
});
