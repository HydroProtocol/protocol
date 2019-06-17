require('../utils/hooks');
const assert = require('assert');
const Hydro = artifacts.require('Hydro.sol');

contract('Ownable', accounts => {
    let hydro;

    before(async () => {
        hydro = await Hydro.deployed();
    });

    it('should return true when caller is owner', async () => {
        const isOwner = await hydro.isOwner({ from: accounts[0] });
        assert.equal(true, isOwner);
    });

    it('should return owner', async () => {
        let owner = await hydro.owner({ from: accounts[0] });
        assert.equal(accounts[0].toLowerCase(), owner.toLowerCase());

        // Should also return the owner properly when called by a non owner account
        owner = await hydro.owner({ from: accounts[2] });
        assert.equal(accounts[0].toLowerCase(), owner.toLowerCase());
    });

    it("should return false when caller isn't owner", async () => {
        const isOwner = await hydro.isOwner({ from: accounts[2] });
        assert.equal(false, isOwner);
    });

    it('should transfer ownership', async () => {
        await hydro.transferOwnership(accounts[3], { from: accounts[0] });
        let isOwner = await hydro.isOwner({ from: accounts[3] });
        assert.equal(true, isOwner);

        // Old owner will no longer be considered the owner
        isOwner = await hydro.isOwner({ from: accounts[0] });
        assert.equal(false, isOwner);
    });

    it("can't transfer ownership to empty address", async () => {
        await assert.rejects(
            hydro.transferOwnership('0x0000000000000000000000000000000000000000', {
                from: accounts[0]
            }),
            /INVALID_OWNER/
        );
    });

    it("can't transfer ownership if not owner", async () => {
        await assert.rejects(hydro.transferOwnership(accounts[3], { from: accounts[3] }), /revert/);
    });

    it('should have no owner after renouncing', async () => {
        await hydro.renounceOwnership({ from: accounts[0] });
        const owner = await hydro.owner({ from: accounts[0] });
        assert.equal('0x0000000000000000000000000000000000000000', owner);
    });

    it('should revert when trying to renounce but not owner', async () => {
        assert.rejects(hydro.renounceOwnership({ from: accounts[1] }), /revert/);
    });
});
