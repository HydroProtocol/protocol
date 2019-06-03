const Hydro = artifacts.require('./Hydro.sol');
const assert = require('assert');
const BigNumber = require('bignumber.js');

const { createAssets } = require('../utils/assets');

const { toWei } = require('../utils');

const { toInterest, getInterestRate } = require('../utils/interest');

const { updateTimestamp } = require('../utils/evm');

const { snapshot, revert } = require('../utils/evm');

contract('Pool', accounts => {
    let hydro;
    let snapshotID;

    before(async () => {
        hydro = await Hydro.deployed();
    });

    beforeEach(async () => {
        snapshotID = await snapshot();
    });

    afterEach(async () => {
        await revert(snapshotID);
    });

    const u1 = accounts[4];
    const u2 = accounts[5];

    beforeEach(async () => {
        hydro = await Hydro.deployed();
        await createAssets([
            {
                symbol: 'ETH',
                oraclePrice: toWei('500'),
                collateralRate: 15000,
                decimals: 18,
                initBalances: {
                    [u2]: toWei('1')
                },
                initCollaterals: {
                    [u2]: toWei('1')
                }
            },
            {
                name: 'USD',
                symbol: 'USD',
                oraclePrice: toWei('1'),
                collateralRate: 15000,
                decimals: 18,
                initBalances: {
                    [u1]: toWei('1000')
                },
                initPool: {
                    [u1]: toWei('1000')
                }
            }
        ]);
    });

    it('basic borrow', async () => {
        const currentTime = Math.floor(Date.now() / 1000);
        const USD = 1;
        const u2Default = await hydro.getUserDefaultAccount.call(u2);

        assert.equal((await hydro.getPoolTotalSupply.call(USD)).toString(), toWei('1000'));
        assert.equal((await hydro.getPoolTotalBorrow.call(USD)).toString(), '0');
        assert.equal((await hydro.getPoolTotalShares.call(USD)).toString(), toWei('1000'));
        assert.equal((await hydro.getPoolSharesOf(USD, u1)).toString(), toWei('1000'));

        // first borrow
        const expiredAt = currentTime + 86400 * 365;
        const res = await hydro.borrowFromPool(
            u2Default,
            USD,
            toWei('100'),
            toInterest(2),
            expiredAt,
            {
                from: u2,
                gas: 500000
            }
        );

        const borrowBlockTime = (await web3.eth.getBlock(res.receipt.blockHash)).timestamp;
        assert.equal((await hydro.getPoolTotalBorrow.call(USD)).toString(), toWei('100'));
        assert.equal(
            (await hydro.getPoolInterestStartTime.call(USD)).toString(),
            borrowBlockTime.toString()
        );

        const expectAnnualInterest = new BigNumber(
            getInterestRate(0.1, expiredAt - borrowBlockTime)
        )
            .multipliedBy(toWei('100'))
            .toString();
        const contractAnnualInterest = (await hydro.getPoolAnnualInterest.call(USD)).toString();
        assert.equal(expectAnnualInterest, contractAnnualInterest);

        // 6 months later
        console.log(borrowBlockTime);
        console.log(currentTime + 86400 * 180);
        console.log(expectAnnualInterest);
        updateTimestamp(currentTime + 86400 * 180);
        console.log((await hydro.getPoolTotalSupply(USD)).toString());
        // const expectedSupply = new BigNumber(expectAnnualInterest).multipliedBy(0.5).
    });
});
