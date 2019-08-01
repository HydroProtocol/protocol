const HDWalletProvider = require('truffle-hdwallet-provider');

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
            provider: () => new HDWalletProvider(process.env.PK, 'https://mainnet.infura.io'),
            network_id: 1,
            gasPrice: 10000000000,
            gas: 4000000
        },
        ropsten: {
            provider: () =>
                new HDWalletProvider(
                    process.env.PK,
                    'https://ropsten.infura.io/v3/d4470e7b7221494caaaa66d3a353c5dc'
                ),
            network_id: 3,
            gas: 8000000,
            gasPrice: 10000000000
        },
        rinkeby: {
            provider: () =>
                new HDWalletProvider(
                    process.env.PK,
                    'https://rinkeby.infura.io/v3/d4470e7b7221494caaaa66d3a353c5dc'
                ),
            network_id: 4,
            gas: 7000000,
            gasPrice: 10000000000
        },
        kovan: {
            provider: () =>
                new HDWalletProvider(
                    process.env.PK,
                    'https://kovan.infura.io/v3/d4470e7b7221494caaaa66d3a353c5dc'
                ),
            network_id: 42,
            gas: 8000000,
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
        }

        // If you have 0.5.8 solc installed locally, you can use the following config to speed up tests.
        //
        //  solc: {
        //     version: 'native'
        //  }
    },
    mocha: {
        enableTimeouts: false,
        useColors: true
    }
};
