const assert = require('assert');
const { isValidSignature } = require('../sdk/sdk');
const { newContract } = require('./utils');
const TestSignature = artifacts.require('./helper/TestSignature.sol');

const { hashPersonalMessage, ecsign, toBuffer, privateToAddress } = require('ethereumjs-util');

contract('Signature', accounts => {
    const privateKey = '0x388c684f0ba1ef5017716adb5d21a053ea8e90277d0868337519f97bede61418';
    const orderHash = '0xaf802826788065ba466dabccd8bda7cea419e59e0acad67662ad013534eb823b';
    let address;
    let contract;

    before(async () => {
        address = bufferToHash(privateToAddress(privateKey));
        contract = await newContract(TestSignature);
    });

    const SignatureType = {
        EthSign: '00',
        EIP712: '01',
        INVALID: '02'
    };
    const bufferToHash = buffer => '0x' + buffer.toString('hex');
    const formatSig = (sig, type) => ({
        config: `0x${sig.v.toString(16)}${type}` + '0'.repeat(60),
        r: sig.r,
        s: sig.s
    });

    it('should be an valid signature (EthSign)', async () => {
        const sha = hashPersonalMessage(toBuffer(orderHash));
        const sig = ecsign(sha, toBuffer(privateKey));

        const isValid = await contract.methods
            .isValidSignaturePublic(orderHash, address, formatSig(sig, SignatureType.EthSign))
            .call();
        assert(isValid);
    });

    it('should be an valid signature (EIP712)', async () => {
        const sha = toBuffer(orderHash);
        const sig = ecsign(sha, toBuffer(privateKey));

        const isValid = await contract.methods
            .isValidSignaturePublic(orderHash, address, formatSig(sig, SignatureType.EIP712))
            .call();
        assert(isValid);
    });

    it('should be an invalid signature (EthSign)', async () => {
        const sha = hashPersonalMessage(toBuffer(orderHash));
        const sig = ecsign(sha, toBuffer(privateKey));

        const wrongOrderHash = '0x0000000000000000000000000000000000000000000000000000000000000000';
        const isValid = await contract.methods
            .isValidSignaturePublic(wrongOrderHash, address, formatSig(sig, SignatureType.EthSign))
            .call();
        assert(!isValid);
    });

    it('should be an invalid signature (EIP712)', async () => {
        const sha = toBuffer(orderHash);
        const sig = ecsign(sha, toBuffer(privateKey));

        const wrongOrderHash = '0x0000000000000000000000000000000000000000000000000000000000000000';
        const isValid = await contract.methods
            .isValidSignaturePublic(wrongOrderHash, address, formatSig(sig, SignatureType.EIP712))
            .call();
        assert(!isValid);
    });

    it('should revert when using an invalid signature type', async () => {
        const sha = toBuffer(orderHash);
        const sig = ecsign(sha, toBuffer(privateKey));

        try {
            const isValid = await contract.methods
                .isValidSignaturePublic(orderHash, address, formatSig(sig, SignatureType.INVALID))
                .call();
        } catch (e) {
            assert.ok(e.message.match(/revert/));
            return;
        }

        assert(false, 'Should never get here');
    });
});
