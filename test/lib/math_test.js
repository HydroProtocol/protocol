const assert = require('assert');
const { newContract } = require('../utils');
const TestMath = artifacts.require('../helper/TestMath.sol');

contract('Math', accounts => {
    let math;

    before(async () => {
        math = await newContract(TestMath);
    });

    it('isRoundingError', async () => {
        let res = await math.methods.isRoundingError(100, 4, 3).call();
        assert.equal(false, res);

        res = await math.methods.isRoundingError(100, 333, 10).call();
        assert.equal(true, res);

        res = await math.methods.isRoundingError(100, 3, 10).call();
        assert.equal(true, res);

        res = await math.methods.isRoundingError(100, 1999, 20).call();
        assert.equal(false, res);
    });

    it('getPartialAmount', async () => {
        let res = await math.methods.getPartialAmountFloor(100, 4, 3).call();
        assert.equal(75, res);

        try {
            await math.methods.getPartialAmountFloor(100, 333, 10).call();
        } catch (e) {
            assert.ok(e.message.match(/revert/));
        }

        try {
            await math.methods.getPartialAmountFloor(100, 3, 10).call();
        } catch (e) {
            assert.ok(e.message.match(/revert/));
        }

        res = await math.methods.getPartialAmountFloor(100, 1999, 20).call();
        assert.equal(1, res);
    });

    it('min', async () => {
        let res = await math.methods.min(100, 99).call();
        assert.equal(99, res);

        res = await math.methods.min(0, 1).call();
        assert.equal(0, res);
    });
});
