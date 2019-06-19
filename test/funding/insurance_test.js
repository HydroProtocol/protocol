require('../utils/hooks');
const assert = require('assert');
const { createAssets, newMarket } = require('../utils/assets');
const { toWei } = require('../utils');
const { mineAt, getBlockTimestamp } = require('../utils/evm');
const Hydro = artifacts.require('./Hydro.sol');
const PriceOracle = artifacts.require('./PriceOracle.sol');

contract('Insurance', accounts => {
    let hydro;
    let ETHAddr;
    let USDAddr;
    let MarketID;
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
        MarketID = 0;
        await hydro.updateInsuranceRatio(toWei('0.1'));
        await hydro.updateMarket(MarketID, toWei('1'), toWei('0.01'), toWei('1.2'), toWei('2'));
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

    beforeEach(async () => {
        await mineAt(async () => hydro.supply(USDAddr, toWei('1000'), { from: u1 }), initTime);
        await addCollateral(u2, ETHAddr, toWei('1'), initTime);
        await mineAt(async () => hydro.borrow(USDAddr, toWei('100'), 0, { from: u2 }), initTime);
    });

    it('check interest rate', async () => {
        interestRate = await hydro.getInterestRates(USDAddr, 0);
        assert.equal(interestRate[0].toString(), toWei(0.025)); // borrow interestRate 2.5%
        assert.equal(interestRate[1].toString(), toWei(0.00225)); // supply interestRate 0.225%
    });

    it('check insurance balance', async () => {
        await mineAt(
            async () => hydro.supply(USDAddr, toWei('1000'), { from: u1 }),
            initTime + 86400 * 90
        );
        assert.equal((await hydro.getInsuranceBalance(USDAddr)).toString(), '61643835616438500');
    });

    const getOracle = async asset => {
        const assetInfo = await hydro.getAsset(asset);
        return PriceOracle.at(assetInfo.priceOracle);
    };

    it('bad debt liquidation [insurance payable]', async () => {
        await mineAt(async () => hydro.updateInsuranceRatio(toWei('0.9')), initTime);
        await mineAt(async () => hydro.borrow(USDAddr, toWei('900'), 0, { from: u2 }), initTime);
        await addCollateral(u2, USDAddr, toWei('20'), initTime + 90 * 86400);
        const oracle = await getOracle(ETHAddr);
        await mineAt(
            async () => oracle.setPrice(ETHAddr, toWei(0), { from: accounts[0] }),
            initTime + 90 * 86400
        );
        await mineAt(async () => hydro.liquidateAccount(u2, 0), initTime + 90 * 86400);
        assert.equal(
            (await hydro.getInsuranceBalance(USDAddr)).toString(),
            '155342465753424658000'
        );
        assert.equal((await hydro.getBorrowOf(USDAddr, u2, 0)).toString(), '152602739726027397000');
        await mineAt(async () => hydro.closeAbortiveAuction(0), initTime + 90 * 86400);
        assert.equal((await hydro.getInsuranceBalance(USDAddr)).toString(), '2739726027397261000');
        assert.equal((await hydro.getBorrowOf(USDAddr, u2, 0)).toString(), '0');
        assert.equal((await hydro.getAccountDetails(u2, 0)).status, '0');
        assert.equal((await hydro.getAccountDetails(u2, 0)).debtsTotalUSDValue, '0');
        assert.equal((await hydro.getAccountDetails(u2, 0)).balancesTotalUSDValue, '0');
    });

    it('bad debt liquidation [insurance non-payable]', async () => {
        await mineAt(async () => hydro.updateInsuranceRatio(toWei('0.9')), initTime);
        await mineAt(async () => hydro.borrow(USDAddr, toWei('900'), 0, { from: u2 }), initTime);
        await addCollateral(u2, USDAddr, toWei('10'), initTime + 90 * 86400);
        const oracle = await getOracle(ETHAddr);
        await mineAt(
            async () => oracle.setPrice(ETHAddr, toWei(0), { from: accounts[0] }),
            initTime + 90 * 86400
        );
        await mineAt(async () => hydro.liquidateAccount(u2, 0), initTime + 90 * 86400);
        assert.equal(
            (await hydro.getInsuranceBalance(USDAddr)).toString(),
            '155342465753424658000'
        );
        assert.equal((await hydro.getBorrowOf(USDAddr, u2, 0)).toString(), '162602739726027397000');
        assert.equal((await hydro.getTotalSupply(USDAddr)).toString(), '1017260273972602739000');
        await mineAt(async () => hydro.closeAbortiveAuction(0), initTime + 90 * 86400);
        assert.equal((await hydro.getInsuranceBalance(USDAddr)).toString(), '0');
        assert.equal((await hydro.getBorrowOf(USDAddr, u2, 0)).toString(), '0');
        assert.equal((await hydro.getAccountDetails(u2, 0)).status, '0');
        assert.equal((await hydro.getAccountDetails(u2, 0)).debtsTotalUSDValue, '0');
        assert.equal((await hydro.getAccountDetails(u2, 0)).balancesTotalUSDValue, '0');
        assert.equal((await hydro.getTotalSupply(USDAddr)).toString(), toWei('1010'));
    });
});
