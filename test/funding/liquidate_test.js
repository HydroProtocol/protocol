require('../utils/hooks');
const assert = require('assert');
const Hydro = artifacts.require('./Hydro.sol');
const PriceOracle = artifacts.require('./PriceOracle.sol');
// const TestToken = artifacts.require('./helper/TestToken.sol');

const { newMarket, depositMarket } = require('../utils/assets');
const { toWei, pp, getUserKey } = require('../utils');
const { mineAt, mine } = require('../utils/evm');
// const { buildOrder } = require('../utils/order');

contract('Liquidate', accounts => {
    let marketID, hydro, oracle, time, ethAsset, usdAsset;

    const CollateralAccountStatus = {
        Normal: 0,
        Liquid: 1
    };

    before(async () => {
        hydro = await Hydro.deployed();
        oracle = await PriceOracle.deployed();
        time = Math.round(new Date().getTime() / 1000) + 1000;
    });

    const relayer = accounts[9];
    const u1 = accounts[4];
    const u2 = accounts[5];
    const u3 = accounts[6];

    beforeEach(async () => {
        const res = await newMarket({
            liquidateRate: toWei('1.2'),
            withdrawRate: toWei('2'),
            assetConfigs: [
                {
                    symbol: 'ETH',
                    name: 'ETH',
                    decimals: 18,
                    oraclePrice: toWei('100'),
                    collateralRate: 15000,
                    initBalances: {
                        [u1]: toWei('30')
                    }
                },
                {
                    symbol: 'USD',
                    name: 'USD',
                    decimals: 18,
                    oraclePrice: toWei('1'),
                    collateralRate: 15000,
                    initBalances: {
                        [u1]: toWei('30000')
                    }
                }
            ],
            initMarketBalances: [
                {
                    [u2]: toWei('1')
                }
            ]
        });

        marketID = res.marketID;
        ethAsset = res.baseAsset;
        usdAsset = res.quoteAsset;

        await mineAt(() => hydro.supplyPool(usdAsset.address, toWei('10000'), { from: u1 }), time);
        await mineAt(() => hydro.supplyPool(ethAsset.address, toWei('10'), { from: u1 }), time);
    });

    it('should be a health position if there is no debt', async () => {
        let accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.liquidable, false);
        assert.equal(accountDetails.status, CollateralAccountStatus.Normal);
        assert.equal(accountDetails.debtsTotalUSDValue, '0');
        assert.equal(accountDetails.balancesTotalUSDValue, toWei('100'));

        await assert.rejects(hydro.liquidateAccount(u1, marketID), /ACCOUNT_NOT_LIQUIDABLE/);
    });

    it("should be a health position if there aren't many debts", async () => {
        await mineAt(
            () => hydro.borrow(usdAsset.address, toWei('100'), marketID, { from: u2 }),
            time
        );
        let accountDetails = await hydro.getAccountDetails(u2, marketID);

        assert.equal(accountDetails.liquidable, false);
        assert.equal(accountDetails.status, CollateralAccountStatus.Normal);
        assert.equal(accountDetails.debtsTotalUSDValue, toWei('100'));
        assert.equal(accountDetails.balancesTotalUSDValue, toWei('200'));

        await assert.rejects(hydro.liquidateAccount(u1, marketID), /ACCOUNT_NOT_LIQUIDABLE/);
    });

    it('should be a unhealthy position if there are too many debts', async () => {
        await mineAt(
            () => hydro.borrow(usdAsset.address, toWei('100'), marketID, { from: u2 }),
            time
        );

        // ether price drop to 10
        await mineAt(
            () =>
                oracle.setPrice(ethAsset.address, toWei('10'), {
                    from: accounts[0]
                }),
            time
        );

        let accountDetails = await hydro.getAccountDetails(u2, marketID);

        assert.equal(accountDetails.liquidable, true);
        assert.equal(accountDetails.status, CollateralAccountStatus.Normal);
        assert.equal(accountDetails.debtsTotalUSDValue, toWei('100'));
        assert.equal(accountDetails.balancesTotalUSDValue, toWei('110'));

        await hydro.liquidateAccount(u2, marketID);
        // account is liquidated
        accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.liquidable, false);
        assert.equal(accountDetails.status, CollateralAccountStatus.Liquid);
    });

    it('liquidation without debt should not result in an auction', async () => {
        await mineAt(
            () => hydro.borrow(usdAsset.address, toWei('100'), marketID, { from: u2 }),
            time
        );

        // u2 has 100 usd debt
        assert.equal(await hydro.getPoolBorrowOf(usdAsset.address, u2, marketID), toWei('100'));

        // ether price drop to 10
        await mineAt(
            () =>
                oracle.setPrice(ethAsset.address, toWei('10'), {
                    from: accounts[0]
                }),
            time
        );

        assert.equal(await hydro.getAuctionsCount(), '0');

        // Since we hack the blocktime, there is no interest occured from borrowed usd asset yet.
        // And u2 hasn't use the usd asset. So his debt can be repaied directly.
        // Finially, there should be no auction, as there is no debt.
        await mineAt(() => hydro.liquidateAccount(u2, marketID), time);

        // u2 debt is force repaied, and no auction created
        assert.equal(await hydro.getPoolBorrowOf(usdAsset.address, u2, marketID), '0');
        assert.equal(await hydro.getAuctionsCount(), '0');

        // u2 account is still useable, status is normal
        accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.status, CollateralAccountStatus.Normal);
    });

    it('liquidation with debt left should result in an auction #1', async () => {
        await mineAt(
            () => hydro.borrow(usdAsset.address, toWei('100'), marketID, { from: u2 }),
            time
        );

        // u2 has 100 usd debt
        assert.equal(await hydro.getPoolBorrowOf(usdAsset.address, u2, marketID), toWei('100'));

        // ether price drop to 10
        await mineAt(
            () =>
                oracle.setPrice(ethAsset.address, toWei('10'), {
                    from: accounts[0]
                }),
            time
        );

        assert.equal(await hydro.getAuctionsCount(), '0');

        // After one day, there is interest occured from borrowed usd asset.
        // And u2 hasn't use the usd asset. But as there is some interest already.
        // Finially, he can't repay the debt.
        await mineAt(() => hydro.liquidateAccount(u2, marketID), time + 86400);

        // u2 should have some usd debt
        assert(
            (await hydro.getPoolBorrowOf(usdAsset.address, u2, marketID)).gt('0'),
            'debt should larger than 0'
        );

        assert.equal(await hydro.getAuctionsCount(), '1');

        // u2 account is liquidated, status is Liqudate
        accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.status, CollateralAccountStatus.Liquid);

        const auctionDetails = await hydro.getAuctionDetails('0');
        assert.equal(auctionDetails.debtAsset, usdAsset.address);
        assert.equal(auctionDetails.collateralAsset, ethAsset.address);
        assert.equal(auctionDetails.leftCollateralAmount, toWei('1'));
        assert.equal(auctionDetails.leftDebtAmount, '561643835616400');
        assert.equal(auctionDetails.ratio, toWei('0.01'));
    });

    it('liquidation with debt left should result in an auction #2', async () => {
        // this test will borrow eth, and use usd as collateral
        await depositMarket(marketID, usdAsset, u2, toWei('100'));
        await hydro.transfer(
            ethAsset.address,
            {
                category: 1,
                marketID,
                user: u2
            },
            {
                category: 0,
                marketID,
                user: u2
            },
            toWei('1'),
            { from: u2 }
        );

        await mineAt(
            () => hydro.borrow(ethAsset.address, toWei('1'), marketID, { from: u2 }),
            time
        );
        // u2 has 1 eth debt
        assert.equal(await hydro.getPoolBorrowOf(ethAsset.address, u2, marketID), toWei('1'));
        // u2 has 100 usd and 1 eth in account
        assert.equal(await hydro.marketBalanceOf(marketID, usdAsset.address, u2), toWei('100'));
        assert.equal(await hydro.marketBalanceOf(marketID, ethAsset.address, u2), toWei('1'));

        // usd price
        await mineAt(
            () =>
                oracle.setPrice(usdAsset.address, toWei('0'), {
                    from: accounts[0]
                }),
            time
        );
        assert.equal(await hydro.getAuctionsCount(), '0');
        // As the price changed, he can't repay the debt.
        await mineAt(() => hydro.liquidateAccount(u2, marketID), time + 86400);
        // u2 should have some eth debt
        assert(
            (await hydro.getPoolBorrowOf(ethAsset.address, u2, marketID)).gt('0'),
            'debt should larger than 0'
        );
        assert.equal(await hydro.getAuctionsCount(), '1');
        // u2 account is liquidated, status is Liqudate
        accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.status, CollateralAccountStatus.Liquid);
        const auctionDetails = await hydro.getAuctionDetails('0');
        assert.equal(auctionDetails.debtAsset, ethAsset.address);
        assert.equal(auctionDetails.collateralAsset, usdAsset.address);
        assert.equal(auctionDetails.leftCollateralAmount, toWei('100'));
        assert.equal(auctionDetails.leftDebtAmount, '68493150684931');
        assert.equal(auctionDetails.ratio, toWei('0.01'));
    });

    it('should not be able to operator to liquidating account', async () => {
        await mineAt(
            () => hydro.borrow(usdAsset.address, toWei('100'), marketID, { from: u2 }),
            time
        );

        // ether price drop to 10
        await mineAt(
            () =>
                oracle.setPrice(ethAsset.address, toWei('10'), {
                    from: accounts[0]
                }),
            time
        );

        await mineAt(() => hydro.liquidateAccount(u2, marketID), time + 86400);

        let accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.status, CollateralAccountStatus.Liquid);

        // can't transfer funds in
        await assert.rejects(
            depositMarket(marketID, usdAsset, u2, toWei('100')),
            /CAN_NOT_OPERATOR_LIQUIDATING_COLLATERAL_ACCOUNT/
        );

        // can't transfer funds out
        await assert.rejects(
            hydro.transfer(
                ethAsset.address,
                {
                    category: 1,
                    marketID,
                    user: u2
                },
                {
                    category: 0,
                    marketID: 0,
                    user: u2
                },
                toWei('1'),
                {
                    from: u2
                }
            ),
            /NO_ENOUGH_TRANSFERABLE_AMOUNT/
        );
    });

    it('should return correct transferable amount #1', async () => {
        await mineAt(
            () => hydro.borrow(usdAsset.address, toWei('50'), marketID, { from: u2 }),
            time
        );

        // Collateral:
        //   1 eth  = 100USD
        //   50 USD = 50USD
        // Debt:
        //   50 USD
        // transferable amount = ((100 + 50) - (50 * 2)) / 100
        assert.equal(
            await hydro.getMarketTransferableAmount(marketID, usdAsset.address, u2),
            toWei('50')
        );

        assert.equal(
            await hydro.getMarketTransferableAmount(marketID, ethAsset.address, u2),
            toWei('0.5')
        );
    });

    it('should return correct transferable amount #2', async () => {
        await mineAt(
            () => hydro.borrow(usdAsset.address, toWei('100'), marketID, { from: u2 }),
            time
        );

        // Collateral:
        //   1 eth  = 100USD
        //   100 USD = 100USD
        // Debt:
        //   100 USD
        // transferable amount = ((100 + 100) - (100 * 2)) / 100
        assert.equal(
            await hydro.getMarketTransferableAmount(marketID, usdAsset.address, u2),
            toWei('0')
        );

        assert.equal(
            await hydro.getMarketTransferableAmount(marketID, ethAsset.address, u2),
            toWei('0')
        );
    });

    it('should return correct transferable amount #3', async () => {
        await mineAt(
            () => hydro.borrow(usdAsset.address, toWei('200'), marketID, { from: u2 }),
            time
        );

        // Collateral:
        //   1 eth  = 100USD
        //   200 USD = 200USD
        // Debt:
        //   200 USD
        assert.equal(
            await hydro.getMarketTransferableAmount(marketID, usdAsset.address, u2),
            toWei('0')
        );

        assert.equal(
            await hydro.getMarketTransferableAmount(marketID, ethAsset.address, u2),
            toWei('0')
        );
    });

    it('should be able to transfer out some asset when the account has more than enough collateral', async () => {
        await mineAt(
            () => hydro.borrow(usdAsset.address, toWei('50'), marketID, { from: u2 }),
            time
        );

        // Collateral:
        //   1 eth  = 100USD
        //   50 USD = 50USD
        // Debt:
        //   50 USD
        // transferable amount = ((100 + 50) - (50 * 2)) / 100
        assert.equal(
            await hydro.getMarketTransferableAmount(marketID, usdAsset.address, u2),
            toWei('50')
        );

        // can withdraw 50 usd
        await mineAt(() => {
            return hydro.transfer(
                usdAsset.address,
                {
                    category: 1,
                    marketID,
                    user: u2
                },
                {
                    category: 0,
                    marketID: 0,
                    user: u2
                },
                toWei('50'),
                { from: u2 }
            );
        }, time);

        // cant't withdraw more
        await assert.rejects(
            mineAt(() => {
                return hydro.transfer(
                    usdAsset.address,
                    {
                        category: 1,
                        marketID,
                        user: u2
                    },
                    {
                        category: 0,
                        marketID: 0,
                        user: u2
                    },
                    toWei('1'), // even 1 USD
                    { from: u2 }
                );
            }, time),
            /NO_ENOUGH_TRANSFERABLE_AMOUNT/
        );
    });

    const createLiquidatingAccount = async () => {
        await mineAt(
            () => hydro.borrow(usdAsset.address, toWei('100'), marketID, { from: u2 }),
            time
        );

        await mineAt(
            () =>
                oracle.setPrice(ethAsset.address, toWei('10000'), {
                    from: accounts[0]
                }),
            time
        );

        await mineAt(() => {
            return hydro.transfer(
                usdAsset.address,
                {
                    category: 1,
                    marketID,
                    user: u2
                },
                {
                    category: 0,
                    marketID: 0,
                    user: u2
                },
                toWei('100'), // even 1 USD
                { from: u2 }
            );
        }, time);

        await mineAt(
            () =>
                oracle.setPrice(ethAsset.address, toWei('100'), {
                    from: accounts[0]
                }),
            time
        );

        // u2 has a 100 USD debt, usd value is 100
        // u2 has a 1 eth collateral, usd value is 100

        let accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(await hydro.isAccountLiquidable(u2, marketID), true);
        assert.equal(accountDetails.liquidable, true);
        assert.equal(accountDetails.status, CollateralAccountStatus.Normal);
        assert.equal(accountDetails.debtsTotalUSDValue, toWei('100'));
        assert.equal(accountDetails.balancesTotalUSDValue, toWei('100'));

        await mineAt(() => hydro.liquidateAccount(u2, marketID), time);

        // u2 account is liquidated, status is Liqudate
        accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.status, CollateralAccountStatus.Liquid);

        const auctionDetails = await hydro.getAuctionDetails('0');
        assert.equal(auctionDetails.debtAsset, usdAsset.address);
        assert.equal(auctionDetails.collateralAsset, ethAsset.address);
        assert.equal(auctionDetails.leftCollateralAmount, toWei('1'));
        assert.equal(auctionDetails.leftDebtAmount, toWei('100'));
        assert.equal(auctionDetails.ratio, toWei('0.01'));
    };

    it('auction', async () => {
        const initiaior = accounts[0];
        await hydro.updateAuctionInitiatorRewardRatio(toWei('0.05'));
        await createLiquidatingAccount();

        for (let i = 0; i < 48; i++) await mine(time);

        let auctionDetails = await hydro.getAuctionDetails('0');

        // the next block number ratio will be 50%
        assert.equal(auctionDetails.ratio, toWei('0.49'));

        const u1USDBalance1 = await hydro.balanceOf(usdAsset.address, u1);
        const u1EthBalance1 = await hydro.balanceOf(ethAsset.address, u1);

        const u2USDBalance1 = await hydro.balanceOf(usdAsset.address, u2);
        const u2EthBalance1 = await hydro.balanceOf(ethAsset.address, u2);

        const initiaiorUSDBalance1 = await hydro.balanceOf(usdAsset.address, initiaior);
        const initiaiorEthBalance1 = await hydro.balanceOf(ethAsset.address, initiaior);

        /////////////////////////////////////////////////////
        // u1 has enough usd, pay 50 USD debt at ratio 50% //
        /////////////////////////////////////////////////////
        await mineAt(() => hydro.fillAuctionWithAmount(0, toWei('50'), { from: u1 }), time);

        const u1USDBalance2 = await hydro.balanceOf(usdAsset.address, u1);
        const u1EthBalance2 = await hydro.balanceOf(ethAsset.address, u1);

        const u2USDBalance2 = await hydro.balanceOf(usdAsset.address, u2);
        const u2EthBalance2 = await hydro.balanceOf(ethAsset.address, u2);

        const initiaiorUSDBalance2 = await hydro.balanceOf(usdAsset.address, initiaior);
        const initiaiorEthBalance2 = await hydro.balanceOf(ethAsset.address, initiaior);

        assert.equal(u1USDBalance2.sub(u1USDBalance1).toString(), toWei('-50'));
        assert.equal(u1EthBalance2.sub(u1EthBalance1).toString(), toWei('0.25')); // 0.5 * (50 / 100)

        assert.equal(u2USDBalance2.sub(u2USDBalance1).toString(), toWei('0'));
        assert.equal(u2EthBalance2.sub(u2EthBalance1).toString(), toWei('0.2375')); // (1 - 0.5) * (50 / 100) * (1 - 0.05)

        assert.equal(initiaiorUSDBalance2.sub(initiaiorUSDBalance1).toString(), toWei('0'));
        assert.equal(initiaiorEthBalance2.sub(initiaiorEthBalance1).toString(), toWei('0.0125')); // (1 - 0.5) * (50 / 100) * (0.05)

        auctionDetails = await hydro.getAuctionDetails('0');
        assert.equal(auctionDetails.leftCollateralAmount, toWei('0.5'));
        assert.equal(auctionDetails.leftDebtAmount, toWei('50'));
        assert.equal(auctionDetails.ratio, toWei('0.5'));

        let accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.status, CollateralAccountStatus.Liquid);
        assert.equal(accountDetails.debtsTotalUSDValue, toWei('50'));
        assert.equal(accountDetails.balancesTotalUSDValue, toWei('50'));

        // 29 blocks later
        for (let i = 0; i < 29; i++) await mine(time);
        auctionDetails = await hydro.getAuctionDetails('0');

        // the next block number ratio will be 80%
        assert.equal(auctionDetails.ratio, toWei('0.79'));

        /////////////////////////////////////
        // u1 pay 50 USD debt at ratio 80% //
        /////////////////////////////////////

        await mineAt(() => hydro.fillAuctionWithAmount(0, toWei('50'), { from: u1 }), time);

        const u1USDBalance3 = await hydro.balanceOf(usdAsset.address, u1);
        const u1EthBalance3 = await hydro.balanceOf(ethAsset.address, u1);

        const u2USDBalance3 = await hydro.balanceOf(usdAsset.address, u2);
        const u2EthBalance3 = await hydro.balanceOf(ethAsset.address, u2);

        const initiaiorUSDBalance3 = await hydro.balanceOf(usdAsset.address, initiaior);
        const initiaiorEthBalance3 = await hydro.balanceOf(ethAsset.address, initiaior);

        assert.equal(u1USDBalance3.sub(u1USDBalance2).toString(), toWei('-50'));
        assert.equal(u1EthBalance3.sub(u1EthBalance2).toString(), toWei('0.4')); // 0.8 * (50 / 100)

        assert.equal(u2USDBalance3.sub(u2USDBalance2).toString(), toWei('0'));
        assert.equal(u2EthBalance3.sub(u2EthBalance2).toString(), toWei('0.095')); // (1 - 0.8) * (50 / 100) * (1 - 0.05)

        assert.equal(initiaiorUSDBalance3.sub(initiaiorUSDBalance2).toString(), toWei('0'));
        assert.equal(initiaiorEthBalance3.sub(initiaiorEthBalance2).toString(), toWei('0.005')); // (1 - 0.8) * (50 / 100) * (0.05)

        // all debt are paid, the auction should be finished
        auctionDetails = await hydro.getAuctionDetails('0');
        assert.equal(auctionDetails.leftCollateralAmount, toWei('0'));
        assert.equal(auctionDetails.leftDebtAmount, toWei('0'));
        assert.equal(auctionDetails.ratio, toWei('0.8'));

        accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.status, CollateralAccountStatus.Normal); // <- return to normal
        assert.equal(accountDetails.debtsTotalUSDValue, toWei('0'));
        assert.equal(accountDetails.balancesTotalUSDValue, toWei('0'));
    });
});
