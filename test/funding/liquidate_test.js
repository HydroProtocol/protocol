require('../utils/hooks');
const assert = require('assert');
const Hydro = artifacts.require('./Hydro.sol');
const Oracle = artifacts.require('./Oracle.sol');
// const TestToken = artifacts.require('./helper/TestToken.sol');

const { newMarket, depositMarket } = require('../utils/assets');
const { toWei, pp, getUserKey } = require('../utils');
const { mineAt } = require('../utils/evm');
// const { buildOrder } = require('../utils/order');

contract('Liquidate', accounts => {
    let marketID, hydro, oracle, time, ethAsset, usdAsset;

    const CollateralAccountStatus = {
        Normal: 0,
        Liquid: 1
    };

    before(async () => {
        hydro = await Hydro.deployed();
        oracle = await Oracle.deployed();
        time = Math.round(new Date().getTime() / 1000) + 1000;
    });

    const relayer = accounts[9];
    const u1 = accounts[4];
    const u2 = accounts[5];
    const u3 = accounts[6];

    beforeEach(async () => {
        const res = await newMarket({
            liquidateRate: 120,
            withdrawRate: 200,
            assetConfigs: [
                {
                    symbol: 'ETH',
                    name: 'ETH',
                    decimals: 18,
                    oraclePrice: toWei('100'),
                    collateralRate: 15000
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
    });

    it('should be a health position if there is no debt', async () => {
        let accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.liquidable, false);
        assert.equal(accountDetails.status, CollateralAccountStatus.Normal);
        assert.equal(accountDetails.debtsTotalUSDValue, '0');
        assert.equal(accountDetails.balancesTotalUSDValue, toWei('100'));

        await hydro.liquidateAccount(u1, marketID);
        // account is not liquidatable, status should be normal
        accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.status, CollateralAccountStatus.Normal);
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

        await hydro.liquidateAccount(u1, marketID);
        // account is not liquidatable, status should be normal
        accountDetails = await hydro.getAccountDetails(u2, marketID);
        assert.equal(accountDetails.status, CollateralAccountStatus.Normal);
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

        await hydro.liquidateAccount(u2, marketID);
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
            /CAN_NOT_OPERATOR_LIQUIDATING_COLLATERAL_ACCOUNT/
        );
    });
});
