require('../utils/hooks');
const assert = require('assert');
const Hydro = artifacts.require('./Hydro.sol');
const { toWei } = require('../utils');
const { createAsset } = require('../utils/assets');
const { transfer, supply, borrow, deposit } = require('../../sdk/sdk.js');

contract('Transfer', accounts => {
    const etherAsset = '0x000000000000000000000000000000000000000E';
    const user = accounts[0];

    it('can not transfer eth to unexist market', async () => {
        // prepare
        await createAsset({
            symbol: 'ETH',
            oraclePrice: toWei('500'),
            collateralRate: 15000,
            decimals: 18,
            initBalances: {
                [user]: toWei('10')
            }
        });
        await deposit(etherAsset, toWei('1'), { from: user, value: toWei('1') });

        // test
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
                    marketID: 1000,
                    user: user
                },
                toWei('1'),
                { from: user }
            ),
            /MARKET_NOT_EXIST/
        );
    });
});

////////////////////////////////////////////////////
// reproduce the critical bug [unristrict borrow] //
////////////////////////////////////////////////////

// contract('Transfer', accounts => {
//     const etherAsset = '0x000000000000000000000000000000000000000E';
//     const user = accounts[0];

//     it('can borrow money from an unexist market', async () => {
//         // prepare
//         hydro = await Hydro.deployed();
//         await createAsset({
//             symbol: 'ETH',
//             oraclePrice: toWei('500'),
//             collateralRate: 15000,
//             decimals: 18,
//             initBalances: {
//                 [user]: toWei('10')
//             }
//         });
//         // await deposit(etherAsset, toWei('10'), { from: user, value: toWei('10') });
//         await supply(etherAsset, toWei('1'), { from: user });

//         // test
//         UnexistMarketID = 1000;
//         await transfer(
//             etherAsset,
//             {
//                 category: 0,
//                 marketID: 0,
//                 user: user
//             },
//             {
//                 category: 1,
//                 marketID: UnexistMarketID,
//                 user: user
//             },
//             toWei('1'),
//             { from: user }
//         );

//         await borrow(UnexistMarketID, etherAsset, toWei('0.1'), { from: user });
//         amountBorrowed = await hydro.getAmountBorrowed(etherAsset, user, UnexistMarketID);
//         assert(amountBorrowed.gt('0'));
//     });
// });
