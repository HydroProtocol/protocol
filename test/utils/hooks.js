const { snapshot, revert, minerStart, isMining } = require('./evm');

let snapshotID;

beforeEach(async () => {
    snapshotID = await snapshot();
});

afterEach(async () => {
    if (snapshotID) {
        await revert(snapshotID);
    }

    snapshotID = undefined;
});

process.on('SIGINT', async () => {
    if (snapshotID) {
        await revert(snapshotID);
    }

    if (!(await isMining())) {
        await minerStart();
    }

    process.exit();
});
