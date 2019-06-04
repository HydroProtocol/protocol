const { snapshot, revert } = require('./evm');

let snapshotID;

beforeEach(async () => {
    snapshotID = await snapshot();
});

afterEach(async () => {
    await revert(snapshotID);
});
