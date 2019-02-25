/*

    Copyright 2018 The Hydro Protocol Foundation

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity ^0.4.24;

/**
 * EIP712 Ethereum typed structured data hashing and signing
 */
contract EIP712 {
    string internal constant DOMAIN_NAME = "Hydro Protocol";

    /**
     * Hash of the EIP712 Domain Separator Schema
     */
    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256(
        abi.encodePacked("EIP712Domain(string name)")
    );

    bytes32 public DOMAIN_SEPARATOR;

    constructor () public {
        DOMAIN_SEPARATOR = keccak256(
            abi.encodePacked(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME))
            )
        );
    }

    /**
     * Calculates EIP712 encoding for a hash struct in this EIP712 Domain.
     *
     * @param eip712hash The EIP712 hash struct.
     * @return EIP712 hash applied to this EIP712 Domain.
     */
    function hashEIP712Message(bytes32 eip712hash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, eip712hash));
    }
}
