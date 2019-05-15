/*

    Copyright 2019 The Hydro Protocol Foundation

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
pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "../lib/EIP712.sol";

contract Orders is EIP712 {
    uint256 public constant INTEREST_RATE_BASE = 10000;
    uint256 public constant FEE_RATE_BASE = 10000;

    struct Order {
        address owner;
        address relayer;
        address loanToken;
        uint256 LoanAmount;

        /**
         * Data contains the following values packed into 32 bytes
         * ╔════════════════════╤═══════════════════════════════════════════════════════════╗
         * ║                    │ length(bytes)   desc                                      ║
         * ╟────────────────────┼───────────────────────────────────────────────────────────╢
         * ║ version            │ 1               order version                             ║
         * ║ type               │ 1               0: lend, 1: borrow                        ║
         * ║ expiredAt          │ 5               order expiration time in seconds          ║
         * ║ loanDuration       │ 5               loan duration in seconds                  ║
         * ║ interestRate       │ 2               interest rate (base 10,000)               ║
         * ║ feeRate            │ 2               fee rate (base 100,00)                    ║
         * ║ salt               │ rest            salt                                      ║
         * ╚════════════════════╧═══════════════════════════════════════════════════════════╝
         */
        bytes32 data;
    }

    bytes32 public constant EIP712_ORDER_TYPE = keccak256(
        abi.encodePacked(
            "Order(address owner,address relayer,address loanToken,uint256 loanAmount,bytes32 data)"
        )
    );

    /**
     * Calculates the Keccak-256 EIP712 hash of the order using the Hydro Protocol domain.
     *
     * @param order The order data struct.
     * @return Fully qualified EIP712 hash of the order in the Hydro Protocol domain.
     */
    function getOrderHash(Order memory order) internal view returns (bytes32 orderHash) {
        orderHash = hashEIP712Message(hashOrder(order));
        return orderHash;
    }

    /**
     * Calculates the EIP712 hash of the order.
     *
     * @param order The order data struct.
     * @return Hash of the order.
     */
    function hashOrder(Order memory order) internal pure returns (bytes32 result) {
        /**
         * Calculate the following hash in solidity assembly to save gas.
         *
         * keccak256(
         *     abi.encodePacked(
         *         EIP712_ORDER_TYPE,
         *         bytes32(order.owner),
         *         bytes32(order.relayer),
         *         bytes32(order.loanToken),
         *         bytes32(order.loanAmount),
         *         order.data
         *     )
         * );
         */

        bytes32 orderType = EIP712_ORDER_TYPE;

        assembly {
            let start := sub(order, 32)
            let tmp := mload(start)

            // 192 = (1 + 5) * 32
            //
            // [0...32)   bytes: EIP712_ORDER_TYPE
            // [32...192) bytes: order
            mstore(start, orderType)
            result := keccak256(start, 192)

            mstore(start, tmp)
        }

        return result;
    }

    /* Functions to extract info from data bytes in Order struct */

    function getOrderVersion(bytes32 data) internal pure returns (uint256) {
        return uint256(uint8(byte(data)));
    }

    function isLoan(bytes32 data) internal pure returns (bool) {
        return uint8(data[1]) == 0;
    }

    function getExpiredAt(bytes32 data) internal pure returns (uint256) {
        return uint256(uint40(bytes5(data << (8*2))));
    }

    function getLoanDuration(bytes32 data) internal pure returns (uint256) {
        return uint256(uint40(bytes5(data << (8*7))));
    }

    function getInterestRate(bytes32 data) internal pure returns (uint256) {
        return uint256(uint16(bytes2(data << (8*12))));
    }

    function getFeeRate(bytes32 data) internal pure returns (uint256) {
        return uint256(uint16(bytes2(data << (8*14))));
    }
}