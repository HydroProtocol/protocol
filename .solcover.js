module.exports = {
    port: 6545,
    skipFiles: [
        'helper/TestMath.sol',
        'helper/TestToken.sol',
        'helper/StandardToken.sol',
        'helper/TestSafeErc20.sol',

        // staticcall doesn't allow to emit events
        // have to skip the three files below
        'PriceOracle.sol',
        'HydroToken.sol',
        'DefaultInterestModel.sol'
    ],
    testrpcOptions: '--port 6545 -g 1'
};
