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
pragma experimental ABIEncoderV2;

import "./lib/SafeMath.sol";
import "./lib/LibOrder.sol";
import "./lib/LibMath.sol";
import "./lib/LibSignature.sol";
import "./lib/LibRelayer.sol";
import "./lib/LibDiscount.sol";
import "./lib/LibExchangeErrors.sol";

contract HybridExchange is LibOrder, LibMath, LibRelayer, LibDiscount, LibExchangeErrors {
    using SafeMath for uint256;

    uint256 public constant FEE_RATE_BASE = 100000;

    /**
     * Address of the proxy responsible for asset transfer.
     */
    address public proxyAddress;

    /**
     * Mapping of orderHash => amount
     * Generally the amount will be specified in base token units, however in the case of a market
     * buy order the amount is specified in quote token units.
     */
    mapping (bytes32 => uint256) public filled;
    /**
     * Mapping of orderHash => whether order has been cancelled.
     */
    mapping (bytes32 => bool) public cancelled;

    event Cancel(bytes32 indexed orderHash);
    event Match(
        address baseToken,
        address quoteToken,
        address relayer,
        address maker,
        address taker,
        uint256 baseTokenAmount,
        uint256 quoteTokenAmount,
        uint256 makerFee,
        uint256 takerFee,
        uint256 makerGasFee,
        uint256 makerRebate,
        uint256 takerGasFee
    );

    struct TotalMatchResult {
        uint256 baseTokenFilledAmount;
        uint256 quoteTokenFilledAmount;
    }

    struct MatchResult {
        address maker;
        address taker;
        uint256 makerFee;
        uint256 makerRebate;
        uint256 takerFee;
        uint256 makerGasFee;
        uint256 takerGasFee;
        uint256 baseTokenFilledAmount;
        uint256 quoteTokenFilledAmount;
    }

    /**
     * When orders are being matched, they will always contain the exact same base token,
     * quote token, and relayer. Since excessive call data is very expensive, we choose
     * to create a stripped down OrderParam struct containing only data that may vary between
     * Order objects, and separate out the common elements into a set of addresses that will
     * be shared among all of the OrderParam items. This is meant to eliminate redundancy in
     * the call data, reducing it's size, and hence saving gas.
     */
    struct OrderParam {
        address trader;
        uint256 baseTokenAmount;
        uint256 quoteTokenAmount;
        uint256 gasTokenAmount;
        bytes32 data;
        OrderSignature signature;
    }

    struct OrderAddressSet {
        address baseToken;
        address quoteToken;
        address relayer;
    }

    /**
     * Calculated data about an order object.
     * Generally the filledAmount is specified in base token units, however in the case of a market
     * buy order the filledAmount is specified in quote token units.
     */
    struct OrderInfo {
        bytes32 orderHash;
        uint256 filledAmount;
    }

    constructor(address _proxyAddress, address hotTokenAddress)
        LibDiscount(hotTokenAddress)
        public
    {
        proxyAddress = _proxyAddress;
    }

    /**
     * Match taker order to a list of maker orders. Common addresses are passed in
     * separately as an OrderAddressSet to reduce call size data and save gas.
     *
     * @param takerOrderParam A OrderParam object representing the order from the taker.
     * @param makerOrderParams An array of OrderParam objects representing orders from a list of makers.
     * @param orderAddressSet An object containing addresses common across each order.
     */
    function matchOrders(
        OrderParam memory takerOrderParam,
        OrderParam[] memory makerOrderParams,
        OrderAddressSet memory orderAddressSet
    ) public {
        require(canMatchOrdersFrom(orderAddressSet.relayer), INVALID_SENDER);

        bool isParticipantRelayer = isParticipant(orderAddressSet.relayer);
        uint256 takerFeeRate = getTakerFeeRate(takerOrderParam, isParticipantRelayer);
        OrderInfo memory takerOrderInfo = getOrderInfo(takerOrderParam, orderAddressSet);

        // Calculate which orders match for settlement.
        MatchResult[] memory results = new MatchResult[](makerOrderParams.length);
        TotalMatchResult memory totalMatch;
        for (uint256 i = 0; i < makerOrderParams.length; i++) {
            require(!isMarketOrder(makerOrderParams[i].data), MAKER_ORDER_CAN_NOT_BE_MARKET_ORDER);
            require(isSell(takerOrderParam.data) != isSell(makerOrderParams[i].data), INVALID_SIDE);
            validatePrice(takerOrderParam, makerOrderParams[i]);

            OrderInfo memory makerOrderInfo = getOrderInfo(makerOrderParams[i], orderAddressSet);

            results[i] = getMatchResult(
                takerOrderParam,
                takerOrderInfo,
                makerOrderParams[i],
                makerOrderInfo,
                takerFeeRate,
                isParticipantRelayer
            );

            // Update TotalMatchResult with new fill amounts
            totalMatch.baseTokenFilledAmount = totalMatch.baseTokenFilledAmount.add(
                results[i].baseTokenFilledAmount
            );
            totalMatch.quoteTokenFilledAmount = totalMatch.quoteTokenFilledAmount.add(
                results[i].quoteTokenFilledAmount
            );

            // Update amount filled for this maker order.
            filled[makerOrderInfo.orderHash] = makerOrderInfo.filledAmount.add(
                results[i].baseTokenFilledAmount
            );
        }

        validateMatchResult(takerOrderParam, totalMatch);
        settleResults(results, takerOrderParam, orderAddressSet);

        // Update amount filled for this taker order.
        filled[takerOrderInfo.orderHash] = takerOrderInfo.filledAmount;
    }

    /**
     * Cancels an order, preventing it from being matched. In practice, matching mode relayers will
     * generally handle cancellation off chain by removing the order from their system, however if
     * the trader wants to ensure the order never goes through, or they no longer trust the relayer,
     * this function may be called to block it from ever matching at the contract level.
     *
     * Emits a Cancel event on success.
     *
     * @param order The order to be cancelled.
     */
    function cancelOrder(Order memory order) public {
        require(order.trader == msg.sender, INVALID_TRADER);

        bytes32 orderHash = getOrderHash(order);
        cancelled[orderHash] = true;

        emit Cancel(orderHash);
    }

    /**
     * Calculates current state of the order. Will revert transaction if this order is not
     * fillable for any reason, or if the order signature is invalid.
     *
     * @param orderParam The OrderParam object containing Order data.
     * @param orderAddressSet An object containing addresses common across each order.
     * @return An OrderInfo object containing the hash and current amount filled
     */
    function getOrderInfo(OrderParam memory orderParam, OrderAddressSet memory orderAddressSet)
        internal
        view
        returns (OrderInfo memory orderInfo)
    {
        Order memory order = getOrderFromOrderParam(orderParam, orderAddressSet);
        orderInfo.orderHash = getOrderHash(order);
        orderInfo.filledAmount = filled[orderInfo.orderHash];
        uint8 status = uint8(OrderStatus.FILLABLE);

        if (!isMarketBuy(order.data) && orderInfo.filledAmount >= order.baseTokenAmount) {
            status = uint8(OrderStatus.FULLY_FILLED);
        } else if (isMarketBuy(order.data) && orderInfo.filledAmount >= order.quoteTokenAmount) {
            status = uint8(OrderStatus.FULLY_FILLED);
        } else if (block.timestamp >= getExpiredAtFromOrderData(order.data)) {
            status = uint8(OrderStatus.EXPIRED);
        } else if (cancelled[orderInfo.orderHash]) {
            status = uint8(OrderStatus.CANCELLED);
        }

        require(status == uint8(OrderStatus.FILLABLE), ORDER_IS_NOT_FILLABLE);
        require(
            isValidSignature(orderInfo.orderHash, orderParam.trader, orderParam.signature),
            INVALID_ORDER_SIGNATURE
        );

        return orderInfo;
    }

    /**
     * Reconstruct an Order object from the given OrderParam and OrderAddressSet objects.
     *
     * @param orderParam The OrderParam object containing the Order data.
     * @param orderAddressSet An object containing addresses common across each order.
     * @return The reconstructed Order object.
     */
    function getOrderFromOrderParam(OrderParam memory orderParam, OrderAddressSet memory orderAddressSet)
        internal
        pure
        returns (Order memory order)
    {
        order.trader = orderParam.trader;
        order.baseTokenAmount = orderParam.baseTokenAmount;
        order.quoteTokenAmount = orderParam.quoteTokenAmount;
        order.gasTokenAmount = orderParam.gasTokenAmount;
        order.data = orderParam.data;
        order.baseToken = orderAddressSet.baseToken;
        order.quoteToken = orderAddressSet.quoteToken;
        order.relayer = orderAddressSet.relayer;
    }

    /**
     * Validates that the maker and taker orders can be matched based on the listed prices.
     *
     * If the taker submitted a sell order, the matching maker order must have a price greater than
     * or equal to the price the taker is willing to sell for.
     *
     * Since the price of an order is computed by order.quoteTokenAmount / order.baseTokenAmount
     * we can establish the following formula:
     *
     *    takerOrder.quoteTokenAmount        makerOrder.quoteTokenAmount
     *   -----------------------------  <=  -----------------------------
     *     takerOrder.baseTokenAmount        makerOrder.baseTokenAmount
     *
     * To avoid precision loss from division, we modify the formula to avoid division entirely.
     * In shorthand, this becomes:
     *
     *   takerOrder.quote * makerOrder.base <= takerOrder.base * makerOrder.quote
     *
     * We can apply this same process to buy orders - if the taker submitted a buy order then
     * the matching maker order must have a price less than or equal to the price the taker is
     * willing to pay. This means we can use the same result as above, but simply flip the
     * sign of the comparison operator.
     *
     * The function will revert the transaction if the orders cannot be matched.
     *
     * @param takerOrderParam The OrderParam object representing the taker's order data
     * @param makerOrderParam The OrderParam object representing the maker's order data
     */
    function validatePrice(OrderParam memory takerOrderParam, OrderParam memory makerOrderParam)
        internal
        pure
    {
        uint256 left = takerOrderParam.quoteTokenAmount.mul(makerOrderParam.baseTokenAmount);
        uint256 right = takerOrderParam.baseTokenAmount.mul(makerOrderParam.quoteTokenAmount);
        require(isSell(takerOrderParam.data) ? left <= right : left >= right, INVALID_MATCH);
    }

    /**
     * Construct a MatchResult from matching taker and maker order data, which will be used when
     * settling the orders and transferring token.
     *
     * @param takerOrderParam The OrderParam object representing the taker's order data
     * @param takerOrderInfo The OrderInfo object representing the current taker order state
     * @param makerOrderParam The OrderParam object representing the maker's order data
     * @param makerOrderInfo The OrderInfo object representing the current maker order state
     * @param takerFeeRate The rate used to calculate the fee charged to the taker
     * @param isParticipantRelayer Whether this relayer is participating in hot discount
     * @return MatchResult object containing data that will be used during order settlement.
     */
    function getMatchResult(
        OrderParam memory takerOrderParam,
        OrderInfo memory takerOrderInfo,
        OrderParam memory makerOrderParam,
        OrderInfo memory makerOrderInfo,
        uint256 takerFeeRate,
        bool isParticipantRelayer
    )
        internal
        view
        returns (MatchResult memory result)
    {
        // This will represent the amount we will be filling in this match. In most cases this will
        // be represented in base token units, but in the market buy case this will be quote token
        // units.
        uint256 filledAmount;

        // Determine the amount of token that will be filled by this match, in both base and quote
        // token units. This is done by checking which order has the least amount of token available
        // to fill or be filled and using that as the base fill amount.
        if(!isMarketBuy(takerOrderParam.data)) {
            filledAmount = min(
                takerOrderParam.baseTokenAmount.sub(takerOrderInfo.filledAmount),
                makerOrderParam.baseTokenAmount.sub(makerOrderInfo.filledAmount)
            );
            result.quoteTokenFilledAmount = convertBaseToQuote(makerOrderParam, filledAmount);
            result.baseTokenFilledAmount = filledAmount;
        } else {
            // In the market buy order case, we have to compare the amount of quote token left in
            // the taker order with the amount of base token left in the maker order. In order to do
            // that we convert from base to quote units in our comparison.
            filledAmount = min(
                takerOrderParam.quoteTokenAmount.sub(takerOrderInfo.filledAmount),
                convertBaseToQuote(
                    makerOrderParam,
                    makerOrderParam.baseTokenAmount.sub(makerOrderInfo.filledAmount)
                )
            );
            result.baseTokenFilledAmount = convertQuoteToBase(makerOrderParam, filledAmount);
            result.quoteTokenFilledAmount = filledAmount;
        }

        // Each order only pays gas once, so only pay gas when nothing has been filled yet.
        if (takerOrderInfo.filledAmount == 0) {
            result.takerGasFee = takerOrderParam.gasTokenAmount;
        }

        if (makerOrderInfo.filledAmount == 0) {
            result.makerGasFee = makerOrderParam.gasTokenAmount;
        }

        // Update filled amount. The filledAmount variable will always be in the correct base or
        // quote unit.
        takerOrderInfo.filledAmount = takerOrderInfo.filledAmount.add(filledAmount);

        result.maker = makerOrderParam.trader;
        result.taker = takerOrderParam.trader;

        // rebateRate uses the same base as fee rates, so can be directly compared
        uint256 rebateRate = getMakerRebateRateFromOrderData(makerOrderParam.data);
        uint256 makerRawFeeRate = getAsMakerFeeRateFromOrderData(makerOrderParam.data);

        if (rebateRate > makerRawFeeRate) {
            // Cap the rebate so it will never exceed the fees paid by the taker.
            uint256 makerRebateRate = min(
                // Don't want to apply discounts to the rebase, so simply multiply by
                // DISCOUNT_RATE_BASE to get it to the correct units.
                rebateRate.sub(makerRawFeeRate).mul(DISCOUNT_RATE_BASE),
                takerFeeRate
            );
            result.makerRebate = result.quoteTokenFilledAmount.mul(makerRebateRate).div(
                FEE_RATE_BASE.mul(DISCOUNT_RATE_BASE)
            );
            // If the rebate rate is higher, maker pays no fees.
            result.makerFee = 0;
        } else {
            // maker fee will be reduced, but still >= 0
            uint256 makerFeeRate = getFinalFeeRate(
                makerOrderParam.trader,
                makerRawFeeRate.sub(rebateRate),
                isParticipantRelayer
            );
            result.makerFee = result.quoteTokenFilledAmount.mul(makerFeeRate).div(
                FEE_RATE_BASE.mul(DISCOUNT_RATE_BASE)
            );
            result.makerRebate = 0;
        }

        result.takerFee = result.quoteTokenFilledAmount.mul(takerFeeRate).div(
            FEE_RATE_BASE.mul(DISCOUNT_RATE_BASE)
        );
    }

    /**
     * Get the rate used to calculate the taker fee.
     *
     * @param orderParam The OrderParam object representing the taker order data.
     * @param isParticipantRelayer Whether this relayer is participating in hot discount.
     * @return The final potentially discounted rate to use for the taker fee.
     */
    function getTakerFeeRate(OrderParam memory orderParam, bool isParticipantRelayer)
        internal
        view
        returns(uint256)
    {
        uint256 rawRate = getAsTakerFeeRateFromOrderData(orderParam.data);
        return getFinalFeeRate(orderParam.trader, rawRate, isParticipantRelayer);
    }

    /**
     * Take a fee rate and calculate the potentially discounted rate for this trader based on
     * HOT token ownership.
     *
     * @param trader The address of the trader who made the order.
     * @param rate The raw rate which we will discount if needed.
     * @param isParticipantRelayer Whether this relayer is participating in hot discount.
     * @return The final potentially discounted rate.
     */
    function getFinalFeeRate(address trader, uint256 rate, bool isParticipantRelayer)
        internal
        view
        returns(uint256)
    {
        if (isParticipantRelayer) {
            return rate.mul(getDiscountedRate(trader));
        } else {
            return rate.mul(DISCOUNT_RATE_BASE);
        }
    }

    /**
     * Take an amount and convert it from base token units to quote token units based on the price
     * in the order param.
     *
     * @param orderParam The OrderParam object containing the Order data.
     * @param amount An amount of base token.
     * @return The converted amount in quote token units.
     */
    function convertBaseToQuote(OrderParam memory orderParam, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return getPartialAmountFloor(
            orderParam.quoteTokenAmount,
            orderParam.baseTokenAmount,
            amount
        );
    }

    /**
     * Take an amount and convert it from quote token units to base token units based on the price
     * in the order param.
     *
     * @param orderParam The OrderParam object containing the Order data.
     * @param amount An amount of quote token.
     * @return The converted amount in base token units.
     */
    function convertQuoteToBase(OrderParam memory orderParam, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return getPartialAmountFloor(
            orderParam.baseTokenAmount,
            orderParam.quoteTokenAmount,
            amount
        );
    }

    /**
     * Validates sanity of match results.
     *
     * This function will revert the transaction if the results cannot be validated.
     *
     * @param takerOrderParam The OrderParam object representing the taker's order data
     * @param totalMatch Accumlated match result data representing how much token will be filled
     */
    function validateMatchResult(OrderParam memory takerOrderParam, TotalMatchResult memory totalMatch)
        internal
        pure
    {
        if (isSell(takerOrderParam.data)) {
            // Ensure we don't attempt to sell more tokens than the taker wished to sell
            require(
                totalMatch.baseTokenFilledAmount <= takerOrderParam.baseTokenAmount,
                TAKER_SELL_BASE_EXCEEDED
            );
        } else {
            // Ensure we don't attempt to buy more tokens than the taker wished to buy
            require(
                totalMatch.quoteTokenFilledAmount <= takerOrderParam.quoteTokenAmount,
                TAKER_MARKET_BUY_QUOTE_EXCEEDED
            );

            // If this isn't a market order, there may be maker orders with a better price. Ensure
            // we use exactly the taker's price in this case (as it is a limit order) by validating
            // that the amount of base token filled also matches.
            if (!isMarketOrder(takerOrderParam.data)) {
                require(
                    totalMatch.baseTokenFilledAmount <= takerOrderParam.baseTokenAmount,
                    TAKER_LIMIT_BUY_BASE_EXCEEDED
                );
            }
        }
    }

    /**
     * Take a list of matches and settle them with the taker order, transferring tokens all tokens
     * and paying all fees necessary to complete the transaction.
     *
     * @param results List of MatchResult objects representing each individual trade to settle.
     * @param takerOrderParam The OrderParam object representing the taker order data.
     * @param orderAddressSet An object containing addresses common across each order.
     */
    function settleResults(
        MatchResult[] memory results,
        OrderParam memory takerOrderParam,
        OrderAddressSet memory orderAddressSet
    )
        internal
    {
        if (isSell(takerOrderParam.data)) {
            settleTakerSell(results, orderAddressSet);
        } else {
            settleTakerBuy(results, orderAddressSet);
        }
    }

    /**
     * Settles a sell order given a list of MatchResult objects. A naive approach would be to take
     * each result, have the taker and maker transfer the appropriate tokens, and then have them
     * each send the appropriate fees to the relayer, meaning that for n makers there would be 4n
     * transactions. Additionally the taker would have to have an allowance set for the quote token
     * in order to pay the fees to the relayer.
     *
     * Instead we do the following:
     *  - Taker transfers the required base token to each maker
     *  - Each maker sends an amount of quote token to the relayer equal to:
     *    [Amount owed to taker] + [Maker fee] + [Maker gas cost] - [Maker rebate amount]
     *  - The relayer will then take all of this quote token and in a single batch transaction
     *    send the appropriate amount to the taker, equal to:
     *    [Total amount owed to taker] - [All taker fees] - [All taker gas costs]
     *
     * Thus in the end the taker will have the full amount of quote token, sans the fee and cost of
     * their share of gas. Each maker will have their share of base token, sans the fee and cost of
     * their share of gas, and will keep their rebate in quote token. The relayer will end up with
     * the fees from the taker and each maker (sans rebate), and the gas costs will pay for the
     * transactions. In this scenario, with n makers there will be 2n + 1 transactions, which will
     * be a significant gas savings over the original method.
     *
     * @param results A list of MatchResult objects representing each individual trade to settle.
     * @param orderAddressSet An object containing addresses common across each order.
     */
    function settleTakerSell(MatchResult[] memory results, OrderAddressSet memory orderAddressSet) internal {
        uint256 totalTakerBaseTokenFilledAmount = 0;

        for (uint256 i = 0; i < results.length; i++) {
            transferFrom(
                orderAddressSet.baseToken,
                results[i].taker,
                results[i].maker,
                results[i].baseTokenFilledAmount
            );

            transferFrom(
                orderAddressSet.quoteToken,
                results[i].maker,
                orderAddressSet.relayer,
                results[i].quoteTokenFilledAmount.
                    add(results[i].makerFee).
                    add(results[i].makerGasFee).
                    sub(results[i].makerRebate)
            );

            totalTakerBaseTokenFilledAmount = totalTakerBaseTokenFilledAmount.add(
                results[i].quoteTokenFilledAmount.sub(results[i].takerFee)
            );

            emitMatchEvent(results[i], orderAddressSet);
        }

        transferFrom(
            orderAddressSet.quoteToken,
            orderAddressSet.relayer,
            results[0].taker,
            totalTakerBaseTokenFilledAmount.sub(results[0].takerGasFee)
        );
    }

    /**
     * Settles a buy order given a list of MatchResult objects. A naive approach would be to take
     * each result, have the taker and maker transfer the appropriate tokens, and then have them
     * each send the appropriate fees to the relayer, meaning that for n makers there would be 4n
     * transactions. Additionally each maker would have to have an allowance set for the quote token
     * in order to pay the fees to the relayer.
     *
     * Instead we do the following:
     *  - Each maker transfers base tokens to the taker
     *  - The taker sends an amount of quote tokens to each maker equal to:
     *    [Amount owed to maker] + [Maker rebate amount] - [Maker fee] - [Maker gas cost]
     *  - Since the taker saved all the maker fees and gas costs, it can then send them as a single
     *    batch transaction to the relayer, equal to:
     *    [All maker and taker fees] + [All maker and taker gas costs] - [All maker rebates]
     *
     * Thus in the end the taker will have the full amount of base token, sans the fee and cost of
     * their share of gas. Each maker will have their share of quote token, including their rebate,
     * but sans the fee and cost of their share of gas. The relayer will end up with the fees from
     * the taker and each maker (sans rebates), and the gas costs will pay for the transactions. In
     * this scenario, with n makers there will be 2n + 1 transactions, which will be a significant
     * gas savings over the original method.
     *
     * @param results A list of MatchResult objects representing each individual trade to settle.
     * @param orderAddressSet An object containing addresses common across each order.
     */
    function settleTakerBuy(MatchResult[] memory results, OrderAddressSet memory orderAddressSet) internal {
        uint256 totalFee = 0;

        for (uint256 i = 0; i < results.length; i++) {
            transferFrom(
                orderAddressSet.baseToken,
                results[i].maker,
                results[i].taker,
                results[i].baseTokenFilledAmount
            );

            transferFrom(
                orderAddressSet.quoteToken,
                results[i].taker,
                results[i].maker,
                results[i].quoteTokenFilledAmount.
                    sub(results[i].makerFee).
                    sub(results[i].makerGasFee).
                    add(results[i].makerRebate)
            );

            totalFee = totalFee.
                add(results[i].takerFee).
                add(results[i].makerFee).
                add(results[i].makerGasFee).
                add(results[i].takerGasFee).
                sub(results[i].makerRebate);

            emitMatchEvent(results[i], orderAddressSet);
        }

        transferFrom(
            orderAddressSet.quoteToken,
            results[0].taker,
            orderAddressSet.relayer,
            totalFee
        );
    }

    /**
     * A helper function to call the transferFrom function in Proxy.sol with solidity assembly.
     * Copying the data in order to make an external call can be expensive, but performing the
     * operations in assembly seems to reduce gas cost.
     *
     * The function will revert the transaction if the transfer fails.
     *
     * @param token The address of the ERC20 token we will be transferring, 0 for ETH.
     * @param from The address we will be transferring from.
     * @param to The address we will be transferring to.
     * @param value The amount of token we will be transferring.
     */
    function transferFrom(address token, address from, address to, uint256 value) internal {
        if (value == 0) {
            return;
        }

        address proxy = proxyAddress;
        uint256 result;

        /**
         * We construct calldata for the `Proxy.transferFrom` ABI.
         * The layout of this calldata is in the table below.
         *
         * ╔════════╤════════╤════════╤═══════════════════╗
         * ║ Area   │ Offset │ Length │ Contents          ║
         * ╟────────┼────────┼────────┼───────────────────╢
         * ║ Header │ 0      │ 4      │ function selector ║
         * ║ Params │ 4      │ 32     │ token address     ║
         * ║        │ 36     │ 32     │ from address      ║
         * ║        │ 68     │ 32     │ to address        ║
         * ║        │ 100    │ 32     │ amount of token   ║
         * ╚════════╧════════╧════════╧═══════════════════╝
         */
        assembly {
            // Keep these so we can restore stack memory upon completion
            let tmp1 := mload(0)
            let tmp2 := mload(4)
            let tmp3 := mload(36)
            let tmp4 := mload(68)
            let tmp5 := mload(100)

            // keccak256('transferFrom(address,address,address,uint256)') bitmasked to 4 bytes
            mstore(0, 0x15dacbea00000000000000000000000000000000000000000000000000000000)
            mstore(4, token)
            mstore(36, from)
            mstore(68, to)
            mstore(100, value)

            // Call Proxy contract transferFrom function using constructed calldata
            result := call(
                gas,   // Forward all gas
                proxy, // Proxy.sol deployment address
                0,     // Don't send any ETH
                0,     // Pointer to start of calldata
                132,   // Length of calldata
                0,     // Output location
                0      // We don't expect any output
            )

            // Restore stack memory
            mstore(0, tmp1)
            mstore(4, tmp2)
            mstore(36, tmp3)
            mstore(68, tmp4)
            mstore(100, tmp5)
        }

        if (result == 0) {
            revert(TRANSFER_FROM_FAILED);
        }
    }

    function emitMatchEvent(MatchResult memory result, OrderAddressSet memory orderAddressSet) internal {
        emit Match(
            orderAddressSet.baseToken,
            orderAddressSet.quoteToken,
            orderAddressSet.relayer,
            result.maker,
            result.taker,
            result.baseTokenFilledAmount,
            result.quoteTokenFilledAmount,
            result.makerFee,
            result.takerFee,
            result.makerGasFee,
            result.makerRebate,
            result.takerGasFee
        );
    }
}