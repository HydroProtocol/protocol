require('../utils/hooks');
const assert = require('assert');
const Hydro = artifacts.require('./Hydro.sol');
const { toWei, logGas } = require('../utils');
const { newMarket, createAsset } = require('../utils/assets');
const { deposit, withdraw, transfer, ActionType, batch } = require('../../sdk/sdk.js');
const Ethers = require('ethers');

contract('Transfer', accounts => {
    let hydro, res;

    const etherAsset = '0x000000000000000000000000000000000000000E';
    const hugeAmount = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    const user = accounts[0];

    const createMarketETHUSD = () => {
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

    it('multiple deposit ether unsuccessfully', async () => {
        const balanceBefore = await hydro.balanceOf(etherAsset, user);
        const amount = toWei('1');
        const encoder = new Ethers.utils.AbiCoder();
        // try to hack batch deposit logic
        const actions = [
            {
                actionType: ActionType.Deposit,
                encodedParams: encoder.encode(['address', 'uint256'], [etherAsset, amount])
            },
            {
                actionType: ActionType.Deposit,
                encodedParams: encoder.encode(['address', 'uint256'], [etherAsset, amount])
            }
        ];

        await assert.rejects(batch(actions, { value: amount }), /MSG_VALUE_AND_AMOUNT_MISMATCH/);
        const balanceAfter = await hydro.balanceOf(etherAsset, user);
        assert.equal(balanceAfter.sub(balanceBefore).toString(), toWei('0'));
    });

    it('multiple deposit ether successfully', async () => {
        const balanceBefore = await hydro.balanceOf(etherAsset, user);
        const amount = toWei('1');
        const encoder = new Ethers.utils.AbiCoder();

        const actions = [
            {
                actionType: ActionType.Deposit,
                encodedParams: encoder.encode(['address', 'uint256'], [etherAsset, amount])
            },
            {
                actionType: ActionType.Deposit,
                encodedParams: encoder.encode(['address', 'uint256'], [etherAsset, amount])
            }
        ];

        await batch(actions, { value: toWei(2) });
        const balanceAfter = await hydro.balanceOf(etherAsset, user);
        assert.equal(balanceAfter.sub(balanceBefore).toString(), toWei('2'));
    });

    it('deposit ether successfully', async () => {
        const balanceBefore = await hydro.balanceOf(etherAsset, user);

        await deposit(etherAsset, toWei('1'), { value: toWei('1') });
        const balanceAfter = await hydro.balanceOf(etherAsset, user);

        assert.equal(balanceAfter.sub(balanceBefore).toString(), toWei('1'));
    });

    it('deposit ether successfully (fallback function)', async () => {
        const balanceBefore = await hydro.balanceOf(etherAsset, user);

        await hydro.send(toWei('1'));
        const balanceAfter = await hydro.balanceOf(etherAsset, user);

        assert.equal(balanceAfter.sub(balanceBefore).toString(), toWei('1'));
    });

    it('deposit ether unsuccessfully', async () => {
        // msg value and amount not equal
        await assert.rejects(
            deposit(etherAsset, toWei('100'), { value: toWei('1') }),
            /MSG_VALUE_AND_AMOUNT_MISMATCH/
        );
    });

    it('deposit token successfully', async () => {
        const { quoteAsset } = await createMarketETHUSD();

        const balanceBefore = await hydro.balanceOf(quoteAsset.address, user);
        assert.equal(balanceBefore.toString(), toWei('0'));

        // have to approve before
        await quoteAsset.approve(hydro.address, hugeAmount);

        res = await deposit(quoteAsset.address, toWei('1'));
        logGas(res, 'deposit');
        const balanceAfter = await hydro.balanceOf(quoteAsset.address, user);

        assert.equal(balanceAfter.sub(balanceBefore).toString(), toWei('1'));
    });

    it('deposit token unsuccessfully (no allowance)', async () => {
        const { quoteAsset } = await createMarketETHUSD();

        // try to deposit hugeAmount
        await assert.rejects(deposit(quoteAsset.address, hugeAmount), /TOKEN_TRANSFER_FROM_ERROR/);
    });

    it('deposit token unsuccessfully (not enough balance)', async () => {
        const { quoteAsset } = await createMarketETHUSD();

        // approve
        await quoteAsset.approve(hydro.address, hugeAmount);

        // try to deposit hugeAmount
        await assert.rejects(deposit(quoteAsset.address, hugeAmount), /TOKEN_TRANSFER_FROM_ERROR/);
    });

    it('withdraw ether successfully', async () => {
        // prepare
        await deposit(etherAsset, toWei('1'), { value: toWei('1') });
        const balanceBefore = await hydro.balanceOf(etherAsset, user);
        assert.equal(balanceBefore.toString(), toWei('1'));

        // test
        await withdraw(etherAsset, toWei('1'));
        const balanceAfter = await hydro.balanceOf(etherAsset, user);

        assert.equal(balanceAfter.toString(), toWei('0'));
    });

    it('withdraw ether unsuccessfully', async () => {
        // prepare
        await deposit(etherAsset, toWei('1'), { value: toWei('1') });
        const balanceBefore = await hydro.balanceOf(etherAsset, user);
        assert.equal(balanceBefore.toString(), toWei('1'));

        // try to withdraw more than owned amount
        await assert.rejects(withdraw(etherAsset, toWei('100')), /BALANCE_NOT_ENOUGH/);

        const balanceAfter = await hydro.balanceOf(etherAsset, user);
        assert.equal(balanceAfter.toString(), toWei('1'));
    });

    it('withdraw token successfully', async () => {
        // prepare
        const { quoteAsset } = await createMarketETHUSD();
        await quoteAsset.approve(hydro.address, hugeAmount);

        await deposit(quoteAsset.address, toWei('1'));
        assert.equal(await hydro.balanceOf(quoteAsset.address, user), toWei('1'));

        // test
        await withdraw(quoteAsset.address, toWei('1'));
        assert.equal(await hydro.balanceOf(quoteAsset.address, user), toWei('0'));
    });

    it('withdraw token unsuccessfully', async () => {
        // prepare
        const { quoteAsset } = await createMarketETHUSD();
        await quoteAsset.approve(hydro.address, hugeAmount);
        await deposit(quoteAsset.address, toWei('1'));
        assert.equal(await hydro.balanceOf(quoteAsset.address, user), toWei('1'));

        // test
        await assert.rejects(withdraw(quoteAsset.address, hugeAmount), /BALANCE_NOT_ENOUGH/);
        assert.equal(await hydro.balanceOf(quoteAsset.address, user), toWei('1'));
    });

    it('transfer ether successfully', async () => {
        // prepare
        await createMarketETHUSD();

        await deposit(etherAsset, toWei('1'), { value: toWei('1') });
        const balanceBefore = await hydro.balanceOf(etherAsset, user);
        assert.equal(balanceBefore.toString(), toWei('1'));

        const marketBalanceBefore = await hydro.marketBalanceOf(0, etherAsset, user);
        assert.equal(marketBalanceBefore.toString(), toWei('0'));

        // test
        res = await transfer(
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

        logGas(res, 'transfer ether (common -> collateralAccount)');

        const balanceAfter = await hydro.balanceOf(etherAsset, user);
        assert.equal(balanceAfter.toString(), toWei('0'));

        const marketBalanceAfter = await hydro.marketBalanceOf(0, etherAsset, user);
        assert.equal(marketBalanceAfter.toString(), toWei('1'));

        const daiAddress = (await createAsset({
            symbol: 'DAI',
            name: 'DAI',
            decimals: 18,
            oraclePrice: toWei('1')
        })).address;
        await hydro.createMarket({
            liquidateRate: toWei('1.2'),
            withdrawRate: toWei('2'),
            baseAsset: daiAddress,
            quoteAsset: etherAsset,
            auctionRatioStart: toWei('0.01'),
            auctionRatioPerBlock: toWei('0.01'),
            borrowEnable: true
        });

        res = await transfer(
            etherAsset,
            {
                category: 1,
                marketID: 0,
                user: user
            },
            {
                category: 1,
                marketID: 1,
                user: user
            },
            toWei('1')
        );

        logGas(res, 'transfer ether (collateralAccount -> collateralAccount)');

        assert.equal((await hydro.marketBalanceOf(1, etherAsset, user)).toString(), toWei('1'));
        assert.equal((await hydro.marketBalanceOf(0, etherAsset, user)).toString(), toWei('0'));
    });

    it('transfer ether unsuccessfully', async () => {
        await createMarketETHUSD();

        const balanceBefore = await hydro.balanceOf(etherAsset, user);
        assert.equal(balanceBefore.toString(), toWei('0'));

        // user has insufficient balance
        await assert.rejects(
            transfer(
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
            ),
            /TRANSFER_BALANCE_NOT_ENOUGH/
        );
    });

    it('transfer token successfully', async () => {
        // prepare
        const { quoteAsset } = await createMarketETHUSD();
        await quoteAsset.approve(hydro.address, hugeAmount);
        await deposit(quoteAsset.address, toWei('1'));

        assert.equal(await hydro.balanceOf(quoteAsset.address, user), toWei('1'));
        assert.equal(await hydro.marketBalanceOf(0, quoteAsset.address, user), toWei('0'));

        // test
        res = await transfer(
            quoteAsset.address,
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

        logGas(res, 'transfer token (common -> collateralAccount)');

        assert.equal(await hydro.balanceOf(quoteAsset.address, user), toWei('0'));
        assert.equal(await hydro.marketBalanceOf(0, quoteAsset.address, user), toWei('1'));

        const daiAddress = (await createAsset({
            symbol: 'DAI',
            name: 'DAI',
            decimals: 18,
            oraclePrice: toWei('1')
        })).address;
        await hydro.createMarket({
            liquidateRate: toWei('1.2'),
            withdrawRate: toWei('2'),
            baseAsset: daiAddress,
            quoteAsset: quoteAsset.address,
            auctionRatioStart: toWei('0.01'),
            auctionRatioPerBlock: toWei('0.01'),
            borrowEnable: true
        });

        res = await transfer(
            quoteAsset.address,
            {
                category: 1,
                marketID: 0,
                user: user
            },
            {
                category: 1,
                marketID: 1,
                user: user
            },
            toWei('1')
        );

        logGas(res, 'transfer ether (collateralAccount -> collateralAccount)');

        assert.equal(
            (await hydro.marketBalanceOf(1, quoteAsset.address, user)).toString(),
            toWei('1')
        );
        assert.equal(
            (await hydro.marketBalanceOf(0, quoteAsset.address, user)).toString(),
            toWei('0')
        );
    });

    it('transfer token unsuccessfully', async () => {
        // prepare
        const { quoteAsset } = await createMarketETHUSD();
        await quoteAsset.approve(hydro.address, hugeAmount);
        await deposit(quoteAsset.address, toWei('1'));

        assert.equal(await hydro.balanceOf(quoteAsset.address, user), toWei('1'));
        assert.equal(await hydro.marketBalanceOf(0, quoteAsset.address, user), toWei('0'));

        // test
        await assert.rejects(
            transfer(
                quoteAsset.address,
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
                toWei('100')
            ),
            /TRANSFER_BALANCE_NOT_ENOUGH/
        );

        assert.equal(await hydro.balanceOf(quoteAsset.address, user), toWei('1'));
        assert.equal(await hydro.marketBalanceOf(0, quoteAsset.address, user), toWei('0'));
    });
});
