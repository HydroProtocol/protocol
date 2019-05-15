pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "../lib/LibSignature.sol";

// Test wrapper

contract TestSignature is LibSignature {
    function isValidSignaturePublic(bytes32 hash, address addr, OrderSignature memory orderSignature)
        public
        pure
        returns (bool)
    {
        return isValidSignature(hash, addr, orderSignature);
    }
}