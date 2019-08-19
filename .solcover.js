module.exports = {
    port: 6545,
    skipFiles: [
        'helper/TestMath.sol',
        'helper/TestToken.sol',
        'helper/StandardToken.sol',
        'helper/TestSafeErc20.sol',

        // staticcall doesn't allow to emit events
        // have to skip the files below
        'helper/PriceOracle.sol',
        'HydroToken.sol',
        'funding/DefaultInterestModel.sol',
        'oracle/DaiPriceOracle.sol',
        'oracle/EthPriceOracle.sol',
        'oracle/ConstPriceOracle.sol'
    ],
    testrpcOptions: '--port 6545 -g 1'
};
