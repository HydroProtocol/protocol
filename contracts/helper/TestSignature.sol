pragma solidity 0.4.24;
pragma experimental ABIEncoderV2;

import "../lib/LibSignature.sol";

// Test wrapper

contract TestSignature is LibSignature {
    function isValidSignaturePublic(bytes32 hash, address addr, OrderSignature orderSignature)
        public
        pure
        returns (bool)
    {
        return isValidSignature(hash, addr, orderSignature);
    }
}