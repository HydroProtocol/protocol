const jsonRpcCall = (method, params = []) =>
    new Promise((resolve, reject) => {
        web3.currentProvider.send(
            {
                method,
                params,
                jsonrpc: '2.0',
                id: new Date().getTime()
            },
            (error, result) => {
                if (error) {
                    reject(error);
                }

                resolve(result.result);
            }
        );
    });

const snapshot = () => jsonRpcCall('evm_snapshot');
const revert = snapshotID => jsonRpcCall('evm_revert', [snapshotID]);
const minerStop = () => jsonRpcCall('miner_stop');
const minerStart = () => jsonRpcCall('miner_start');
const mine = timestamp => jsonRpcCall('evm_mine', timestamp ? [timestamp] : []);

const mineAt = async (fn, timestamp) => {
    await minerStop();

    try {
        const promise = fn();
        await mine(timestamp);
        await promise;
    } finally {
        await minerStart();
    }
};

const mineEmptyBlock = async count => {
    const finish = [];

    for (let i = 0; i < count; i++) {
        finish.push(mine());
    }

    return Promise.all(finish);
};

const updateTimestamp = timestamp =>
    new Promise((resolve, reject) => {
        web3.currentProvider.send(
            {
                method: 'evm_mine',
                params: [timestamp],
                jsonrpc: '2.0',
                id: new Date().getTime()
            },
            (error, result) => {
                if (error) {
                    reject(error);
                }

                resolve(result.result);
            }
        );
    });

module.exports = {
    jsonRpcCall,
    revert,
    snapshot,
    updateTimestamp
};
