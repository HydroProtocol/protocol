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

import "./SafeMath.sol";
import "./EIP712.sol";
import "./Math.sol";
import "./Consts.sol";
import "./Signature.sol";
import "../interfaces/OracleInterface.sol";

library Types {
    enum LoanSource {
        Pool,
        P2P
    }

    enum CollateralAccountStatus {
        Normal,
        Liquid,
        Closed
    }

    enum ExchangeOrderStatus {
        EXPIRED,
        CANCELLED,
        FILLABLE,
        FULLY_FILLED
    }

    struct Asset {
        address tokenAddress;
        uint256 collerateRate;
        OracleInterface oracle;
    }

    struct LoanItem {
        address lender;
        uint16 interestRate;
        uint256 amount;
        bytes32 lenderOrderHash;
    }

    // When someone borrows some asset from a source
    // A Loan is created to record the details
    struct Loan {
        uint32 id;
        uint16 assetID;
        uint32 collateralAccountID;
        uint40 startAt;
        uint40 expiredAt;

        // in pool model, it's the commonn interest rate
        // in p2p source, it's a average interest rate
        uint16 interestRate;

        // pool or p2p
        LoanSource source;

        // amount of borrowed asset
        uint256 amount;
    }

    struct CollateralAccount {
        uint32 id;

        CollateralAccountStatus status;

        // liquidation rate
        uint16 liquidateRate;

        address owner;

        // in a margin account, there is only one loan
        // in a lending account, there will be multi loans
        uint32[] loanIDs;

        // assetID => assetAmount
        mapping(uint16 => uint256) collateralAssetAmounts;
    }

    // memory only
    struct CollateralAccountDetails {
        bool       liquidable;
        uint256[]  collateralAssetAmounts;
        Loan[]     loans;
        uint256[]  loanValues;
        uint256    loansTotalUSDValue;
        uint256    collateralsTotalUSDlValue;
    }

    struct Auction {
        uint32 id;
        // To calculate the ratio
        uint32 startBlockNumber;

        uint32 loanID;

        address borrower;

        // The amount of loan when the auction is created, and it's unmodifiable.
        uint256 totalLoanAmount;

        // assets under liquidated, and it's unmodifiable.
        mapping(uint256 => uint256) assetAmounts;
    }

    struct ExchangeOrder {
        address trader;
        address relayer;
        address baseToken;
        address quoteToken;
        uint256 baseTokenAmount;
        uint256 quoteTokenAmount;
        uint256 gasTokenAmount;

        /**
         * Data contains the following values packed into 32 bytes
         * ╔════════════════════╤═══════════════════════════════════════════════════════════╗
         * ║                    │ length(bytes)   desc                                      ║
         * ╟────────────────────┼───────────────────────────────────────────────────────────╢
         * ║ version            │ 1               order version                             ║
         * ║ side               │ 1               0: buy, 1: sell                           ║
         * ║ isMarketOrder      │ 1               0: limitOrder, 1: marketOrder             ║
         * ║ expiredAt          │ 5               order expiration time in seconds          ║
         * ║ asMakerFeeRate     │ 2               maker fee rate (base 100,000)             ║
         * ║ asTakerFeeRate     │ 2               taker fee rate (base 100,000)             ║
         * ║ makerRebateRate    │ 2               rebate rate for maker (base 100)          ║
         * ║ salt               │ 8               salt                                      ║
         * ║ isMakerOnly        │ 1               is maker only                             ║
         * ║                    │ 9               reserved                                  ║
         * ╚════════════════════╧═══════════════════════════════════════════════════════════╝
         */
        bytes32 data;
    }

        /**
     * When orders are being matched, they will always contain the exact same base token,
     * quote token, and relayer. Since excessive call data is very expensive, we choose
     * to create a stripped down OrderParam struct containing only data that may vary between
     * Order objects, and separate out the common elements into a set of addresses that will
     * be shared among all of the OrderParam items. This is meant to eliminate redundancy in
     * the call data, reducing it's size, and hence saving gas.
     */
    struct ExchangeOrderParam {
        address trader;
        uint256 baseTokenAmount;
        uint256 quoteTokenAmount;
        uint256 gasTokenAmount;
        bytes32 data;
        Signature.OrderSignature signature;
    }


    struct ExchangeOrderAddressSet {
        address baseToken;
        address quoteToken;
        address relayer;
    }

    struct ExchangeMatchResult {
        address maker;
        address taker;
        address buyer;
        uint256 makerFee;
        uint256 makerRebate;
        uint256 takerFee;
        uint256 makerGasFee;
        uint256 takerGasFee;
        uint256 baseTokenFilledAmount;
        uint256 quoteTokenFilledAmount;
    }
    /**
     * @param takerOrderParam A Types.ExchangeOrderParam object representing the order from the taker.
     * @param makerOrderParams An array of Types.ExchangeOrderParam objects representing orders from a list of makers.
     * @param orderAddressSet An object containing addresses common across each order.
     */
    struct ExchangeMatchParams {
        ExchangeOrderParam       takerOrderParam;
        ExchangeOrderParam[]     makerOrderParams;
        uint256[]                baseTokenFilledAmounts;
        ExchangeOrderAddressSet  orderAddressSet;
    }
}

library Asset {
    function getPrice(Types.Asset storage asset) internal view returns (uint256) {
        return asset.oracle.getPrice(asset.tokenAddress);
    }
}

library Loan {
    using SafeMath for uint256;

    function isOverdue(Types.Loan memory loan, uint256 time) internal pure returns (bool) {
        return loan.expiredAt < time;
    }

    /**
     * Get loan interest with given amount and timestamp
     * Result should divide (Consts.INTEREST_RATE_BASE * Consts.SECONDS_OF_YEAR)
     */
    function interest(Types.Loan memory loan, uint256 amount, uint40 currentTimestamp) internal pure returns (uint256) {
        uint40 timeDelta = currentTimestamp - loan.startAt;
        return amount.mul(loan.interestRate).mul(timeDelta);
    }
}

library Auction {
    function ratio(Types.Auction memory auction) internal view returns (uint256) {
        uint256 currentRatio = block.number - auction.startBlockNumber;
        return currentRatio < 100 ? currentRatio : 100;
    }
}


library ExchangeOrder {

    bytes32 public constant EIP712_ORDER_TYPE = keccak256(
        abi.encodePacked(
            "Order(address trader,address relayer,address baseToken,address quoteToken,uint256 baseTokenAmount,uint256 quoteTokenAmount,uint256 gasTokenAmount,bytes32 data)"
        )
    );

    /**
     * Calculates the Keccak-256 EIP712 hash of the order using the Hydro Protocol domain.
     *
     * @param order The order data struct.
     * @return Fully qualified EIP712 hash of the order in the Hydro Protocol domain.
     */
    function getHash(Types.ExchangeOrder memory order) internal pure returns (bytes32 orderHash) {
        orderHash = EIP712.hashMessage(_hashContent(order));
        return orderHash;
    }

    /**
     * Calculates the EIP712 hash of the order.
     *
     * @param order The order data struct.
     * @return Hash of the order.
     */
    function _hashContent(Types.ExchangeOrder memory order) internal pure returns (bytes32 result) {
        /**
         * Calculate the following hash in solidity assembly to save gas.
         *
         * keccak256(
         *     abi.encodePacked(
         *         EIP712_ORDER_TYPE,
         *         bytes32(order.trader),
         *         bytes32(order.relayer),
         *         bytes32(order.baseToken),
         *         bytes32(order.quoteToken),
         *         order.baseTokenAmount,
         *         order.quoteTokenAmount,
         *         order.gasTokenAmount,
         *         order.data
         *     )
         * );
         */

        bytes32 orderType = EIP712_ORDER_TYPE;

        assembly {
            let start := sub(order, 32)
            let tmp := mload(start)

            // 288 = (1 + 8) * 32
            //
            // [0...32)   bytes: EIP712_ORDER_TYPE
            // [32...288) bytes: order
            mstore(start, orderType)
            result := keccak256(start, 288)

            mstore(start, tmp)
        }

        return result;
    }
}

library ExchangeOrderParam {
    /* Functions to extract info from data bytes in Order struct */

    function getOrderVersion(Types.ExchangeOrderParam memory order) internal pure returns (uint256) {
        return uint256(uint8(byte(order.data)));
    }

    function getExpiredAtFromOrderData(Types.ExchangeOrderParam memory order) internal pure returns (uint256) {
        return uint256(uint40(bytes5(order.data << (8*3))));
    }

    function isSell(Types.ExchangeOrderParam memory order) internal pure returns (bool) {
        return uint8(order.data[1]) == 1;
    }

    function isMarketOrder(Types.ExchangeOrderParam memory order) internal pure returns (bool) {
        return uint8(order.data[2]) == 1;
    }

    function isMakerOnly(Types.ExchangeOrderParam memory order) internal pure returns (bool) {
        return uint8(order.data[22]) == 1;
    }

    function isMarketBuy(Types.ExchangeOrderParam memory order) internal pure returns (bool) {
        return !isSell(order) && isMarketOrder(order);
    }

    function getAsMakerFeeRateFromOrderData(Types.ExchangeOrderParam memory order) internal pure returns (uint256) {
        return uint256(uint16(bytes2(order.data << (8*8))));
    }

    function getAsTakerFeeRateFromOrderData(Types.ExchangeOrderParam memory order) internal pure returns (uint256) {
        return uint256(uint16(bytes2(order.data << (8*10))));
    }

    function getMakerRebateRateFromOrderData(Types.ExchangeOrderParam memory order) internal pure returns (uint256) {
        uint256 makerRebate = uint256(uint16(bytes2(order.data << (8*12))));

        // make sure makerRebate will never be larger than REBATE_RATE_BASE, which is 100
        return Math.min(makerRebate, Consts.REBATE_RATE_BASE());
    }
}