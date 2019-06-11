module.exports = {
    port: 6545,
    skipFiles: [
        'helper/TestMath.sol',
        'helper/TestToken.sol',
        'helper/StandardToken.sol',
        'lib/Consts.sol'
    ],
    testrpcOptions: '--port 6545 -g 1'
};
