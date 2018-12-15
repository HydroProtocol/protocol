module.exports = {
    port: 6545,
    // norpc: true, // node_modules/.bin/testrpc-sc -p 6545 --gasLimit 17592186044415
    skipFiles: [
        'helper/TestMath.sol',
        'helper/TestOrder.sol',
        'helper/TestSignature.sol',
        'helper/TestToken.sol',
        'helper/WethToken.sol'
    ]
};
