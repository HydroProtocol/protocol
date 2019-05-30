const Hydro = artifacts.require('./Hydro.sol');
const assert = require('assert');

const { createAssets } = require('../utils/assets');
const { toWei } = require('../utils');

contract('Loans', accounts => {
    let hydro;

    const relayer = accounts[9];

    const u1 = accounts[4];
    const u2 = accounts[5];
    const u3 = accounts[6];

    before(async () => {
        hydro = await Hydro.deployed();
    });

    beforeEach(async () => {
        await createAssets([
            {
                symbol: 'ETH',
                oraclePrice: toWei('500'),
                initBalances: {
                    [u2]: toWei('1')
                },
                initCollaterals: {
                    [u2]: toWei('1')
                }
            },
            {
                name: 'USD',
                oraclePrice: toWei('1'),
                symbol: 'USD',
                decimals: 18,
                initBalances: {
                    [u1]: toWei(500), // user1 capital
                    [u2]: toWei(100), // for user2 to pay interest
                    [u3]: toWei(1000)
                }
            },
            {
                name: 'HOT',
                oraclePrice: toWei('0.1'),
                symbol: 'HOT',
                decimals: 18,
                initBalances: {
                    [u2]: toWei(5000) // for user2 to pledge
                },
                initCollaterals: {
                    [u2]: toWei(5000) // for user2 to pledge
                }
            }
        ]);
    });

    it('borrow from pool', async () => {
        assert.equal(true, true);
    });
});
