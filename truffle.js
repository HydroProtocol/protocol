var PrivateKeyProvider = require('truffle-privatekey-provider');
const defaultPK = 'C9BB560DD118EA503E59BE5A25FE422009F68379D70A40F6CA10773FAB0821E8';

module.exports = {
    networks: {
        development: {
            host: '127.0.0.1',
            port: 8545,
            network_id: '*',
            gas: 10000000,
            gasPrice: 1
        },
        production: {
            provider: new PrivateKeyProvider(process.env.PK || defaultPK, 'https://mainnet.infura.io'),
            network_id: 1,
            gasPrice: 10000000000,
            gas: 4000000
        },
        ropsten: {
            provider: new PrivateKeyProvider(defaultPK, 'https://ropsten.infura.io'),
            network_id: 3,
            gasPrice: 10000000000
        },
        coverage: {
            host: 'localhost',
            network_id: '*',
            port: 6545,
            gas: 0xfffffffffff,
            gasPrice: 0x01
        }
    },
    solc: {
        optimizer: {
            enabled: true,
            runs: 1000000
        }
    },
    mocha: {
        enableTimeouts: false
    }
};
