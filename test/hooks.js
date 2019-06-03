const { snapshot, revert } = require('./utils/evm');

let snapshotID;

beforeEach(async () => {
    snapshotID = await snapshot();
});

afterEach(async () => {
    await revert(snapshotID);
});
