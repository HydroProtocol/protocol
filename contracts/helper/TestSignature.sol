pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "../lib/Signature.sol";

// Test wrapper

contract TestSignature {
    function isValidSignaturePublic(bytes32 hash, address addr, Signature.OrderSignature memory orderSignature)
        public
        pure
        returns (bool)
    {
        return Signature.isValidSignature(hash, addr, orderSignature);
    }
}