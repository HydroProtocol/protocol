const Hydro = artifacts.require('./Hydro.sol');
const assert = require('assert');

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
        snapshotID = await snapshot();
        await createAssets([
            {
                symbol: 'ETH',
                oraclePrice: toWei('500'),
                collateralRate: 15000,
                decimals: 18,
                initBalances: {
                    [u2]: toWei('10')
                },
                initCollaterals: {
                    [u2]: toWei('10')
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

    afterEach(async () => {
        await revert(snapshotID);
    });

    const u1 = accounts[4];
    const u2 = accounts[5];

    /*
    0. u1 first supply
    1. u2 first borrow
    2. 6 months later u2 second borrow
    3. 3 months later u1 second supply
    4. u1 withdraw
    */
    it('basic borrow', async () => {
        const initTime = 1560000000;
        const USD = 1;
        const u2Default = await hydro.getUserDefaultAccount.call(u2);

        // check init status
        assert.equal((await hydro.getPoolTotalSupply.call(USD)).toString(), toWei('1000'));
        assert.equal((await hydro.getPoolTotalBorrow.call(USD)).toString(), '0');
        assert.equal((await hydro.getPoolTotalShares.call(USD)).toString(), toWei('1000'));
        assert.equal((await hydro.getPoolSharesOf(USD, u1)).toString(), toWei('1000'));

        // first borrow
        await updateTimestamp(initTime);
        await hydro.borrowFromPool(
            u2Default,
            USD,
            toWei('100'),
            toInterest(2),
            initTime + 86400 * 365,
            {
                from: u2,
                gas: 500000
            }
        );

        assert.equal((await hydro.getPoolTotalBorrow.call(USD)).toString(), toWei('100'));
        assert.equal(
            (await hydro.getPoolInterestStartTime.call(USD)).toString(),
            initTime.toString()
        );
        // first annualInterest = getInterestRate(0.1, 86400 * 365) * 100 = 102.5
        assert.equal((await hydro.getPoolAnnualInterest.call(USD)).toString(), toWei('102.5'));

        // 6 months later second borrow
        await updateTimestamp(initTime + 86400 * 180);
        await hydro.borrowFromPool(
            u2Default,
            USD,
            toWei('200'),
            toInterest(2),
            initTime + 86400 * 180 + 86400 * 365,
            {
                from: u2,
                gas: 500000
            }
        );

        // check total borrow
        assert.equal((await hydro.getPoolTotalBorrow.call(USD)).toString(), toWei('300'));

        // accumulate interest = 102.5*180/365 = 50547945205479452054
        assert.equal(
            (await hydro.getPoolTotalSupply.call(USD)).toString(),
            '1050547945205479452054'
        );

        // second annualInterest = getInterestRate(0.28556526274612074586, 86400 * 365) * 200 = 219.56
        // total annualInterest = 219.56 + 102.5 = 322.06
        assert.equal((await hydro.getPoolAnnualInterest.call(USD)).toString(), toWei('322.06'));

        // 3 months later second supply
        await updateTimestamp(initTime + 86400 * 270);
        await hydro.deposit(1, toWei('500'), { from: u1 });

        assert.equal(
            (await hydro.getPoolTotalSupply.call(USD)).toString(),
            '1629959999999999999999'
        );
        assert.equal((await hydro.getPoolTotalShares.call(USD)).toString(), toWei('1000'));
        assert.equal((await hydro.getPoolSharesOf(USD, u1)).toString(), toWei('1000'));

        // console.log(currentTime + 86400 * 180)
        // console.log((await web3.eth.getBlock(res.receipt.blockHash)).timestamp)

        // borrowBlockTime = (await web3.eth.getBlock(res.receipt.blockHash)).timestamp;
        // var secondBorrowInterest = new BigNumber(
        //         getInterestRate(0.2, expiredAt - borrowBlockTime)
        //     )
        //     .multipliedBy(toWei('100'))
        //     .plus(firstBorrowInterest)
        //     .toString();
        // contractAnnualInterest = (await hydro.getPoolAnnualInterest.call(
        //     USD
        // )).toString();
        // assert.equal(contractAnnualInterest, secondBorrowInterest);

        // supply more
        // await depositPool();
        // console.log(borrowBlockTime);
        // console.log(currentTime + 86400 * 180);
        // console.log(expectAnnualInterest);
        // console.log((await hydro.getPoolTotalSupply(USD)).toString());
        // const expectedSupply = new BigNumber(expectAnnualInterest).multipliedBy(0.5).
    });
});
