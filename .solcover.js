module.exports = {
    port: 6545,
    skipFiles: [
        'helper/TestMath.sol',
        'helper/TestToken.sol',
        'helper/StandardToken.sol',
        'helper/TestSafeErc20.sol',
        'lib/Consts.sol'
    ],
    testrpcOptions: '--port 6545 -g 1'
};
