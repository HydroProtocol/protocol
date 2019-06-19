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
const isMining = () => jsonRpcCall('eth_mining');
const mineAt = async (fn, timestamp) => {
    await minerStop();

    try {
        const promise = fn();
        await new Promise(resolve => setTimeout(resolve, 100));
        await mine(timestamp);
        return await promise;
    } finally {
        await minerStart();
    }
};

const getBlockTimestamp = async () => {
    return (await web3.eth.getBlock(await web3.eth.getBlockNumber())).timestamp;
};

module.exports = {
    jsonRpcCall,
    revert,
    snapshot,
    mine,
    mineAt,
    getBlockTimestamp,
    minerStart,
    isMining
};
