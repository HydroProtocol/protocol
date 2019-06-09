// require('../utils/hooks');
// const Hydro = artifacts.require('./Hydro.sol');
// const assert = require('assert');
// const { createAssets } = require('../utils/assets');
// const { toWei } = require('../utils');
// const { toInterest, getInterestRate } = require('../utils/interest');
// const { updateTimestamp } = require('../utils/evm');
// const { snapshot, revert } = require('../utils/evm');

// contract('Pool', accounts => {
//     let hydro;
//     let u2Default;
//     const u1 = accounts[4];
//     const u2 = accounts[5];
//     const USD = 1;

//     beforeEach(async () => {
//         hydro = await Hydro.deployed();
//         await createAssets([
//             {
//                 symbol: 'ETH',
//                 oraclePrice: toWei('500'),
//                 collateralRate: 15000,
//                 decimals: 18,
//                 initBalances: {
//                     [u2]: toWei('10')
//                 },
//                 initCollaterals: {
//                     [u2]: toWei('10')
//                 }
//             },
//             {
//                 name: 'USD',
//                 symbol: 'USD',
//                 oraclePrice: toWei('1'),
//                 collateralRate: 15000,
//                 decimals: 18,
//                 initBalances: {
//                     [u1]: toWei('1000')
//                 },
//                 initPool: {
//                     [u1]: toWei('1000')
//                 }
//             }
//         ]);
//         u2Default = await hydro.getUserDefaultAccount.call(u2);
//     });

//     it('can not borrow more than supply', async () => {
//         try {
//             await hydro.borrowFromPool(
//                 u2Default,
//                 USD,
//                 toWei('2000'),
//                 toInterest(2),
//                 Math.ceil(new Date().getTime() / 1000) + 86400,
//                 {
//                     from: u2,
//                     gas: 500000
//                 }
//             );
//         } catch (e) {
//             assert.equal((await hydro.getPoolTotalBorrow.call(USD)).toString(), '0');
//             assert.ok(e.message.match(/BORROW_EXCEED_LIMITATION/));
//             return;
//         }
//     });

//     it('can not borrow more than collateral', async () => {
//         // try {
//         //     await hydro.
//         // }
//     });

//     /*
//     0. u1 first supply
//     1. u2 first borrow
//     2. 6 months later u2 second borrow
//     3. 6 months later u1 withdraw and supply again
//     */
//     it('multi-borrow and withdraw supply', async () => {
//         const initTime = Math.ceil(new Date().getTime() / 1000);

//         // check init status
//         assert.equal((await hydro.getPoolTotalSupply.call(USD)).toString(), toWei('1000'));
//         assert.equal((await hydro.getPoolTotalBorrow.call(USD)).toString(), '0');
//         assert.equal((await hydro.getPoolTotalShares.call(USD)).toString(), toWei('1000'));
//         assert.equal((await hydro.getPoolSharesOf(USD, u1)).toString(), toWei('1000'));

//         // first borrow
//         await updateTimestamp(initTime);
//         await hydro.borrowFromPool(
//             u2Default,
//             USD,
//             toWei('100'),
//             toInterest(2),
//             initTime + 86400 * 365,
//             {
//                 from: u2,
//                 gas: 500000
//             }
//         );

//         assert.equal((await hydro.getPoolTotalBorrow.call(USD)).toString(), toWei('100'));
//         assert.equal(
//             (await hydro.getPoolInterestStartTime.call(USD)).toString(),
//             initTime.toString()
//         );
//         // first annualInterest = getInterestRate(0.1, 86400 * 365) * 100 = 102.5
//         assert.equal((await hydro.getPoolAnnualInterest.call(USD)).toString(), toWei('102.5'));

//         // 6 months later second borrow
//         await updateTimestamp(initTime + 86400 * 180);
//         await hydro.borrowFromPool(
//             u2Default,
//             USD,
//             toWei('200'),
//             toInterest(2),
//             initTime + 86400 * 180 + 86400 * 365,
//             {
//                 from: u2,
//                 gas: 500000
//             }
//         );

//         // check total borrow
//         assert.equal((await hydro.getPoolTotalBorrow.call(USD)).toString(), toWei('300'));

//         // accumulate interest = 102.5*180/365 = 50547945205479452054
//         assert.equal(
//             (await hydro.getPoolTotalSupply.call(USD)).toString(),
//             '1050547945205479452054'
//         );

//         // second annualInterest = getInterestRate(0.28556526274612074586, 86400 * 365) * 200 = 219.56
//         // total annualInterest = 219.56 + 102.5 = 322.06
//         assert.equal((await hydro.getPoolAnnualInterest.call(USD)).toString(), toWei('322.06'));

//         // 6 months later withdraw
//         await updateTimestamp(initTime + 86400 * 360);
//         await hydro.poolWithdraw(USD, toWei('500'), { from: u1 });

//         // new interest 158824109589041095890
//         // total supply 1209372054794520547944
//         assert.equal(
//             (await hydro.getPoolTotalSupply.call(USD)).toString(),
//             '604686027397260273972'
//         );
//         assert.equal((await hydro.getPoolTotalShares.call(USD)).toString(), toWei('500'));

//         // keep block time unchanged and supply
//         await updateTimestamp(initTime + 86400 * 360);
//         await hydro.poolSupply(USD, toWei('100'), { from: u1 });
//         assert.equal(
//             (await hydro.getPoolTotalShares.call(USD)).toString(),
//             '582687539871252102302'
//         );
//     });
// });
