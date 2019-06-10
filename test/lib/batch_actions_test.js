const assert = require('assert');
const Hydro = artifacts.require('./Hydro.sol');
const Ethers = require('ethers');
const { toWei } = require('../utils');
const encoder = new Ethers.utils.AbiCoder();

contract('Batch', accounts => {
    let hydro;

    const ActionType = {
        Deposit: 0,
        Withdraw: 1,
        Transfer: 2,
        Borrow: 3,
        Repay: 4,
        Supply: 5,
        Unsupply: 6
    };

    before(async () => {
        hydro = await Hydro.deployed();
    });

    it('deposit', async () => {
        const etherAsset = '0x0000000000000000000000000000000000000000';
        const user = accounts[0];

        const balanceBefore = await hydro.balanceOf(etherAsset, user);
        const actions = [
            {
                actionType: ActionType.Deposit,
                encodedParams: encoder.encode(['address', 'uint256'], [etherAsset, toWei('1')])
            }
        ];

        await hydro.batch(actions, { value: toWei('1') });
        const balanceAfter = await hydro.balanceOf(etherAsset, user);

        assert.equal(balanceAfter.sub(balanceBefore).toString(), toWei('1'));
    });
});
