const snapshot = () =>
    new Promise((resolve, reject) => {
        web3.currentProvider.send({
                method: 'evm_snapshot',
                params: [],
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

const mineEmptyBlock = async count => {
    const mine = () =>
        new Promise((resolve, reject) => {
            web3.currentProvider.send({
                    method: 'evm_mine',
                    params: [],
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

    const finish = [];

    for (let i = 0; i < count; i++) {
        finish.push(mine());
    }

    return Promise.all(finish);
};

const updateTimestamp = timestamp =>
    new Promise((resolve, reject) => {
        web3.currentProvider.send({
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

const recover = snapshotID =>
    new Promise((resolve, reject) => {
        web3.currentProvider.send({
                method: 'evm_revert',
                params: [snapshotID],
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
    recover,
    snapshot
};