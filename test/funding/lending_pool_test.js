require('../utils/hooks');
const assert = require('assert');
const { createAssets, newMarket } = require('../utils/assets');
const { toWei } = require('../utils');
const { mineAt, mine, getBlockTimestamp } = require('../utils/evm');
const Hydro = artifacts.require('./Hydro.sol');
const LendingPoolToken = artifacts.require('./funding/LendingPoolToken.sol');

// const getInterestRates = borrowRatio => {
//     const interestRate = 0.2 * borrowRatio + 0.5 * borrowRatio ** 2;
//     return Math.floor(interestRate * 10000) / 10000;
// };

contract('LendingPool', accounts => {
    let hydro;
    let ETHAddr;
    let USDAddr;
    let initTime;
    const u1 = accounts[4];
    const u2 = accounts[5];

    beforeEach(async () => {
        hydro = await Hydro.deployed();
        tokens = await createAssets([
            {
                symbol: 'ETH',
                oraclePrice: toWei('500'),
                collateralRate: 15000,
                decimals: 18,
                initBalances: {
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
                    [u1]: toWei('10000'),
                    [u2]: toWei('100')
                }
            }
        ]);
        ETHAddr = tokens[0].address;
        USDAddr = tokens[1].address;
        await newMarket({
            assets: [{ address: ETHAddr }, { address: USDAddr }]
        });
        initTime = await getBlockTimestamp();
    });

    const addCollateral = async (user, asset, amount, timestamp) => {
        await mineAt(
            async () =>
                hydro.transfer(
                    asset,
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
                    amount,
                    {
                        from: user
                    }
                ),
            timestamp
        );
    };

    const getLendingPoolToken = async assetAddress => {
        const assetInfo = await hydro.getAsset(assetAddress);
        return LendingPoolToken.at(assetInfo.lendingPoolToken);
    };

    beforeEach(async () => {
        await mineAt(async () => hydro.supply(USDAddr, toWei('1000'), { from: u1 }), initTime);
        await addCollateral(u2, ETHAddr, toWei('1'), initTime);
        await mineAt(async () => hydro.borrow(USDAddr, toWei('100'), 0, { from: u2 }), initTime);
    });

    ////////////////
    // Basic Test //
    ////////////////
    it('mint and burn pool token', async () => {
        poolToken = await getLendingPoolToken(USDAddr);
        assert.equal((await poolToken.balanceOf(u1)).toString(), toWei('1000'));
        assert.equal((await poolToken.totalSupply()).toString(), toWei('1000'));
        await mineAt(async () => hydro.unsupply(USDAddr, toWei('500'), { from: u1 }), initTime);
        assert.equal((await poolToken.balanceOf(u1)).toString(), toWei('500'));
        assert.equal((await poolToken.totalSupply()).toString(), toWei('500'));
    });

    it('check interest rate', async () => {
        interestRate = await hydro.getInterestRates(USDAddr, 0);
        assert.equal(interestRate[0].toString(), toWei(0.025)); // borrow interestRate 2.5%
        assert.equal(interestRate[1].toString(), toWei(0.0025)); // supply interestRate 0.25%'
        // test interest accumulate in 90 days
        await mine(initTime + 86400 * 90);
        assert.equal((await hydro.getTotalSupply(USDAddr)).toString(), '1000616438356164383000');
        assert.equal((await hydro.getSupplyOf(USDAddr, u1)).toString(), '1000616438356164383000');
        assert.equal((await hydro.getTotalBorrow(USDAddr)).toString(), '100616438356164383500');
        assert.equal((await hydro.getBorrowOf(USDAddr, u2, 0)).toString(), '100616438356164383500');
    });

    it('borrow', async () => {
        await mineAt(
            () =>
                hydro.borrow(USDAddr, toWei('100'), 0, { from: u2 }).then(tx => {
                    console.log(`borrow gas cost ${tx.receipt.gasUsed}`);
                }),
            initTime + 86400 * 180
        );
        assert.equal((await hydro.marketBalanceOf(0, USDAddr, u2)).toString(), toWei('200'));
        assert.equal((await hydro.getBorrowOf(USDAddr, u2, 0)).toString(), '201232876712328767100');
        // test wether use principle with interest to calculate new interest rate
        interestRate = await hydro.getInterestRates(USDAddr, 0);
        assert.equal(interestRate[0].toString(), '60394519949755790'); // borrow
        assert.equal(interestRate[1].toString(), '12138397839128643'); // supply
    });

    it('repay', async () => {
        await mineAt(
            async () =>
                hydro.repay(USDAddr, toWei('50'), 0, { from: u2 }).then(tx => {
                    console.log(`repay gas cost ${tx.receipt.gasUsed}`);
                }),
            initTime + 86400 * 180
        );
        assert.equal((await hydro.marketBalanceOf(0, USDAddr, u2)).toString(), toWei('50'));
        assert.equal((await hydro.getBorrowOf(USDAddr, u2, 0)).toString(), '51232876712328767100');
    });

    it('supply', async () => {
        await mineAt(
            () =>
                hydro.supply(USDAddr, toWei('1000'), { from: u1 }).then(tx => {
                    console.log(`supply gas cost ${tx.receipt.gasUsed}`);
                }),
            initTime + 86400 * 180
        );

        poolToken = await getLendingPoolToken(USDAddr);
        assert.equal((await poolToken.balanceOf(u1)).toString(), '1998768641401012450526');
    });

    it('withdraw', async () => {
        await mineAt(
            async () =>
                hydro.unsupply(USDAddr, toWei('500'), { from: u1 }).then(tx => {
                    console.log(`withdraw gas cost ${tx.receipt.gasUsed}`);
                }),
            initTime + 86400 * 180
        );
        assert.equal((await hydro.balanceOf(USDAddr, u1)).toString(), toWei('9500'));
        poolToken = await getLendingPoolToken(USDAddr);
        assert.equal((await poolToken.balanceOf(u1)).toString(), '500615679299493774737');
    });

    it('repay all and withdraw all', async () => {
        await addCollateral(u2, USDAddr, toWei('10'), initTime);
        await mineAt(
            async () =>
                hydro.repay(USDAddr, toWei('1000'), 0, { from: u2 }).then(tx => {
                    console.log(`repay all gas cost ${tx.receipt.gasUsed}`);
                }),
            initTime + 86400 * 180
        );
        // charge 1232876712328767100 as interest
        assert.equal(
            (await hydro.marketBalanceOf(0, USDAddr, u2)).toString(),
            '8767123287671232900'
        );
        assert.equal((await hydro.getBorrowOf(USDAddr, u2, 0)).toString(), '0');
        await mineAt(
            async () =>
                hydro.unsupply(USDAddr, toWei('2000'), { from: u1 }).then(tx => {
                    console.log(`withdraw all gas cost ${tx.receipt.gasUsed}`);
                }),
            initTime + 86400 * 180
        );

        assert.equal((await hydro.balanceOf(USDAddr, u1)).toString(), '10001232876712328767000'); // 100 wei remains in the system because of precision
        poolToken = await getLendingPoolToken(USDAddr);
        assert.equal((await poolToken.balanceOf(u1)).toString(), '0');
    });

    //////////////////////
    // Revert Case Test //
    //////////////////////
    it('can not borrow more than collateral', async () => {
        await hydro.supply(USDAddr, toWei('5000'), { from: u1 });
        await assert.rejects(
            hydro.borrow(USDAddr, toWei('3000'), 0, { from: u2 }),
            /MARKET_ACCOUNT_IS_LIQUIDABLE_AFTER_BORROW/
        );
    });

    it('can not borrow more than supply', async () => {
        await addCollateral(u2, ETHAddr, toWei('5'), initTime);
        await assert.rejects(
            mineAt(() => hydro.borrow(USDAddr, toWei('1000'), 0, { from: u2 }), initTime),
            /BORROW_EXCEED_SUPPLY/
        );
    });

    it('can not withdraw from pool if free inventory not enough', async () => {
        await mineAt(async () => hydro.borrow(USDAddr, toWei('100'), 0, { from: u2 }), initTime);
        await assert.rejects(
            mineAt(async () => hydro.unsupply(USDAddr, toWei('1000'), { from: u1 }), initTime),
            /BORROW_EXCEED_SUPPLY/
        );
    });
});
