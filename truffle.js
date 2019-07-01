var PrivateKeyProvider = require('truffle-privatekey-provider');

module.exports = {
    networks: {
        development: {
            host: '127.0.0.1',
            port: 8545,
            network_id: '*',
            gas: 0xfffffffffff,
            gasPrice: 1
        },
        production: {
            provider: () => new PrivateKeyProvider(process.env.PK, 'https://mainnet.infura.io'),
            network_id: 1,
            gasPrice: 10000000000,
            gas: 4000000
        },
        ropsten: {
            provider: () =>
                new PrivateKeyProvider(
                    process.env.PK,
                    'https://ropsten.infura.io/v3/d4470e7b7221494caaaa66d3a353c5dc'
                ),
            network_id: 3,
            gas: 7001200,
            gasPrice: 10000000000
        },
        rinkeby: {
            provider: () => new PrivateKeyProvider(process.env.PK, 'https://rinkeby.infura.io'),
            network_id: 4,
            gasPrice: 10000000000
        },
        coverage: {
            host: '127.0.0.1',
            port: 6545,
            network_id: '*',
            gas: 0xfffffffffff,
            gasPrice: 1
        }
    },
    compilers: {
        solc: {
            version: '0.5.8',
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200
                }
            }
        },

        // If you have 0.5.8 solc installed locally, you can use the following config to speed up tests.
        //
        solc: {
            version: 'native',
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200
                }
            }
        }
    },
    mocha: {
        enableTimeouts: false,
        useColors: true
    }
};
