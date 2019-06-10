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

pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "./Relayer.sol";

import "../lib/SafeMath.sol";
import "../lib/Math.sol";
import "../lib/Signature.sol";
import "../lib/Errors.sol";
import "../lib/Store.sol";
import "../lib/Types.sol";
import "../lib/Transfer.sol";
import "../lib/Events.sol";
import "../lib/Transfer.sol";

import "./Discount.sol";


library Exchange {
    using SafeMath for uint256;
    using Order for Types.Order;
    using OrderParam for Types.OrderParam;

    /**
     * Calculated data about an order object.
     * Generally the filledAmount is specified in base token units, however in the case of a market
     * buy order the filledAmount is specified in quote token units.
     */
    struct OrderInfo {
        bytes32 orderHash;
        uint256 filledAmount;
        Types.WalletPath walletPath;
    }

    /**
     * Match taker order to a list of maker orders. Common addresses are passed in
     * separately as an Types.OrderAddressSet to reduce call size data and save gas.
     */
    function matchOrders(
        Store.State storage state,
        Types.MatchParams memory params
    )
        internal
        returns (Types.MatchSettleResult memory)
    {
        require(Relayer.canMatchOrdersFrom(state, params.orderAddressSet.relayer), Errors.INVALID_SENDER());
        require(!params.takerOrderParam.isMakerOnly(), Errors.MAKER_ONLY_ORDER_CANNOT_BE_TAKER());

        bool isParticipantRelayer = Relayer.isParticipant(state, params.orderAddressSet.relayer);
        uint256 takerFeeRate = getTakerFeeRate(state, params.takerOrderParam, isParticipantRelayer);
        OrderInfo memory takerOrderInfo = getOrderInfo(state, params.takerOrderParam, params.orderAddressSet);

        // Calculate which orders match for settlement.
        Types.MatchResult[] memory results = new Types.MatchResult[](params.makerOrderParams.length);

        for (uint256 i = 0; i < params.makerOrderParams.length; i++) {
            require(!params.makerOrderParams[i].isMarketOrder(), Errors.MAKER_ORDER_CAN_NOT_BE_MARKET_ORDER());
            require(params.takerOrderParam.isSell() != params.makerOrderParams[i].isSell(), Errors.INVALID_SIDE());
            validatePrice(params.takerOrderParam, params.makerOrderParams[i]);

            OrderInfo memory makerOrderInfo = getOrderInfo(state, params.makerOrderParams[i], params.orderAddressSet);

            results[i] = getMatchResult(
                state,
                params.takerOrderParam,
                takerOrderInfo,
                params.makerOrderParams[i],
                makerOrderInfo,
                params.baseTokenFilledAmounts[i],
                takerFeeRate,
                isParticipantRelayer
            );

            // Update amount filled for this maker order.
            state.exchange.filled[makerOrderInfo.orderHash] = makerOrderInfo.filledAmount;
        }

        // Update amount filled for this taker order.
        state.exchange.filled[takerOrderInfo.orderHash] = takerOrderInfo.filledAmount;

        return settleResults(state, results, params.takerOrderParam, params.orderAddressSet);
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
    function cancelOrder(
        Store.State storage state,
        Types.Order memory order
    )
        internal
    {
        require(order.trader == msg.sender, Errors.INVALID_TRADER());

        bytes32 orderHash = order.getHash();
        state.exchange.cancelled[orderHash] = true;

        Events.logOrderCancel(orderHash);
    }

    /**
     * Calculates current state of the order. Will revert transaction if this order is not
     * fillable for any reason, or if the order signature is invalid.
     *
     * @param orderParam The Types.OrderParam object containing Order data.
     * @param orderAddressSet An object containing addresses common across each order.
     * @return An OrderInfo object containing the hash and current amount filled
     */
    function getOrderInfo(
        Store.State storage state,
        Types.OrderParam memory orderParam,
        Types.OrderAddressSet memory orderAddressSet
    )
        internal
        view
        returns (OrderInfo memory orderInfo)
    {
        require(orderParam.getOrderVersion() == Consts.SUPPORTED_ORDER_VERSION(), Errors.ORDER_VERSION_NOT_SUPPORTED());

        Types.Order memory order = getOrderFromOrderParam(orderParam, orderAddressSet);
        orderInfo.orderHash = order.getHash();
        orderInfo.filledAmount = state.exchange.filled[orderInfo.orderHash];
        uint8 status = uint8(Types.OrderStatus.FILLABLE);

        if (!orderParam.isMarketBuy() && orderInfo.filledAmount >= order.baseTokenAmount) {
            status = uint8(Types.OrderStatus.FULLY_FILLED);
        } else if (orderParam.isMarketBuy() && orderInfo.filledAmount >= order.quoteTokenAmount) {
            status = uint8(Types.OrderStatus.FULLY_FILLED);
        } else if (block.timestamp >= orderParam.getExpiredAtFromOrderData()) {
            status = uint8(Types.OrderStatus.EXPIRED);
        } else if (state.exchange.cancelled[orderInfo.orderHash]) {
            status = uint8(Types.OrderStatus.CANCELLED);
        }

        require(status == uint8(Types.OrderStatus.FILLABLE), Errors.ORDER_IS_NOT_FILLABLE());
        require(
            Signature.isValidSignature(orderInfo.orderHash, orderParam.trader, orderParam.signature),
            Errors.INVALID_ORDER_SIGNATURE()
        );

        orderInfo.walletPath = orderParam.getWalletPathFromOrderData();

        return orderInfo;
    }

    /**
     * Reconstruct an Order object from the given Types.OrderParam and Types.OrderAddressSet objects.
     *
     * @param orderParam The Types.OrderParam object containing the Order data.
     * @param orderAddressSet An object containing addresses common across each order.
     * @return The reconstructed Order object.
     */
    function getOrderFromOrderParam(
        Types.OrderParam memory orderParam,
        Types.OrderAddressSet memory orderAddressSet
    )
        internal
        pure
        returns (Types.Order memory order)
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
     * @param takerOrderParam The Types.OrderParam object representing the taker's order data
     * @param makerOrderParam The Types.OrderParam object representing the maker's order data
     */
    function validatePrice(
        Types.OrderParam memory takerOrderParam,
        Types.OrderParam memory makerOrderParam
    )
        internal
        pure
    {
        uint256 left = takerOrderParam.quoteTokenAmount.mul(makerOrderParam.baseTokenAmount);
        uint256 right = takerOrderParam.baseTokenAmount.mul(makerOrderParam.quoteTokenAmount);
        require(takerOrderParam.isSell() ? left <= right : left >= right, Errors.INVALID_MATCH());
    }

    /**
     * Construct a Types.MatchResult from matching taker and maker order data, which will be used when
     * settling the orders and transferring token.
     *
     * @param takerOrderParam The Types.OrderParam object representing the taker's order data
     * @param takerOrderInfo The OrderInfo object representing the current taker order state
     * @param makerOrderParam The Types.OrderParam object representing the maker's order data
     * @param makerOrderInfo The OrderInfo object representing the current maker order state
     * @param takerFeeRate The rate used to calculate the fee charged to the taker
     * @param isParticipantRelayer Whether this relayer is participating in hot discount
     * @return Types.MatchResult object containing data that will be used during order settlement.
     */
    function getMatchResult(
        Store.State storage state,
        Types.OrderParam memory takerOrderParam,
        OrderInfo memory takerOrderInfo,
        Types.OrderParam memory makerOrderParam,
        OrderInfo memory makerOrderInfo,
        uint256 baseTokenFilledAmount,
        uint256 takerFeeRate,
        bool isParticipantRelayer
    )
        internal
        view
        returns (Types.MatchResult memory result)
    {
        result.baseTokenFilledAmount = baseTokenFilledAmount;
        result.quoteTokenFilledAmount = convertBaseToQuote(makerOrderParam, baseTokenFilledAmount);

        result.takerWalletPath = takerOrderInfo.walletPath;
        result.makerWalletPath = makerOrderInfo.walletPath;

        // Each order only pays gas once, so only pay gas when nothing has been filled yet.
        if (takerOrderInfo.filledAmount == 0) {
            result.takerGasFee = takerOrderParam.gasTokenAmount;
        }

        if (makerOrderInfo.filledAmount == 0) {
            result.makerGasFee = makerOrderParam.gasTokenAmount;
        }

        if(!takerOrderParam.isMarketBuy()) {
            takerOrderInfo.filledAmount = takerOrderInfo.filledAmount.add(result.baseTokenFilledAmount);
            require(takerOrderInfo.filledAmount <= takerOrderParam.baseTokenAmount, Errors.TAKER_ORDER_OVER_MATCH());
        } else {
            takerOrderInfo.filledAmount = takerOrderInfo.filledAmount.add(result.quoteTokenFilledAmount);
            require(takerOrderInfo.filledAmount <= takerOrderParam.quoteTokenAmount, Errors.TAKER_ORDER_OVER_MATCH());
        }

        makerOrderInfo.filledAmount = makerOrderInfo.filledAmount.add(result.baseTokenFilledAmount);
        require(makerOrderInfo.filledAmount <= makerOrderParam.baseTokenAmount, Errors.MAKER_ORDER_OVER_MATCH());

        result.maker = makerOrderParam.trader;
        result.taker = takerOrderParam.trader;

        if(takerOrderParam.isSell()) {
            result.buyer = result.maker;
        } else {
            result.buyer = result.taker;
        }

        uint256 rebateRate = makerOrderParam.getMakerRebateRateFromOrderData();

        if (rebateRate > 0) {
            // If the rebate rate is not zero, maker pays no fees.
            result.makerFee = 0;

            // RebateRate will never exceed REBATE_RATE_BASE, so rebateFee will never exceed the fees paid by the taker.
            result.makerRebate = result.quoteTokenFilledAmount.mul(takerFeeRate).mul(rebateRate).div(
                Consts.EXCHANGE_FEE_RATE_BASE().mul(Consts.DISCOUNT_RATE_BASE()).mul(Consts.REBATE_RATE_BASE())
            );
        } else {
            uint256 makerRawFeeRate = makerOrderParam.getAsMakerFeeRateFromOrderData();
            result.makerRebate = 0;

            // maker fee will be reduced, but still >= 0
            uint256 makerFeeRate = getFinalFeeRate(
                state,
                makerOrderParam.trader,
                makerRawFeeRate,
                isParticipantRelayer
            );

            result.makerFee = result.quoteTokenFilledAmount.mul(makerFeeRate).div(
                Consts.EXCHANGE_FEE_RATE_BASE().mul(Consts.DISCOUNT_RATE_BASE())
            );
        }

        result.takerFee = result.quoteTokenFilledAmount.mul(takerFeeRate).div(
            Consts.EXCHANGE_FEE_RATE_BASE().mul(Consts.DISCOUNT_RATE_BASE())
        );
    }

    /**
     * Get the rate used to calculate the taker fee.
     *
     * @param orderParam The Types.OrderParam object representing the taker order data.
     * @param isParticipantRelayer Whether this relayer is participating in hot discount.
     * @return The final potentially discounted rate to use for the taker fee.
     */
    function getTakerFeeRate(
        Store.State storage state,
        Types.OrderParam memory orderParam,
        bool isParticipantRelayer
    )
        internal
        view
        returns(uint256)
    {
        uint256 rawRate = orderParam.getAsTakerFeeRateFromOrderData();
        return getFinalFeeRate(state, orderParam.trader, rawRate, isParticipantRelayer);
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
    function getFinalFeeRate(
        Store.State storage state,
        address trader,
        uint256 rate,
        bool isParticipantRelayer
    )
        internal
        view
        returns(uint256)
    {
        if (isParticipantRelayer) {
            return rate.mul(Discount.getDiscountedRate(state, trader));
        } else {
            return rate.mul(Consts.DISCOUNT_RATE_BASE());
        }
    }

    /**
     * Take an amount and convert it from base token units to quote token units based on the price
     * in the order param.
     *
     * @param orderParam The Types.OrderParam object containing the Order data.
     * @param amount An amount of base token.
     * @return The converted amount in quote token units.
     */
    function convertBaseToQuote(
        Types.OrderParam memory orderParam,
        uint256 amount
    )
        internal
        pure
        returns (uint256)
    {
        return Math.getPartialAmountFloor(
            orderParam.quoteTokenAmount,
            orderParam.baseTokenAmount,
            amount
        );
    }

    /**
     * Take an amount and convert it from quote token units to base token units based on the price
     * in the order param.
     *
     * @param orderParam The Types.OrderParam object containing the Order data.
     * @param amount An amount of quote token.
     * @return The converted amount in base token units.
     */
    function convertQuoteToBase(Types.OrderParam memory orderParam, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return Math.getPartialAmountFloor(
            orderParam.baseTokenAmount,
            orderParam.quoteTokenAmount,
            amount
        );
    }

    /**
     * Take a list of matches and settle them with the taker order, transferring tokens all tokens
     * and paying all fees necessary to complete the transaction.
     *
     * @param results List of Types.MatchResult objects representing each individual trade to settle.
     * @param takerOrderParam The Types.OrderParam object representing the taker order data.
     * @param orderAddressSet An object containing addresses common across each order.
     */
    function settleResults(
        Store.State storage state,
        Types.MatchResult[] memory results,
        Types.OrderParam memory takerOrderParam,
        Types.OrderAddressSet memory orderAddressSet
    )
        internal
        returns (Types.MatchSettleResult memory)
    {
        if (takerOrderParam.isSell()) {
            return settleTakerSell(state, results, orderAddressSet);
        } else {
            return settleTakerBuy(state, results, orderAddressSet);
        }
    }

    /**
     * Settles a sell order given a list of Types.MatchResult objects. A naive approach would be to take
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
     * @param results A list of Types.MatchResult objects representing each individual trade to settle.
     * @param orderAddressSet An object containing addresses common across each order.
     */
    function settleTakerSell(
        Store.State storage state,
        Types.MatchResult[] memory results,
        Types.OrderAddressSet memory orderAddressSet
    )
        internal
        returns (Types.MatchSettleResult memory settleResult)
    {
        settleResult.incomeToken = orderAddressSet.quoteToken;
        settleResult.outputToken = orderAddressSet.baseToken;

        uint256 totalTakerQuoteTokenFilledAmount = 0;
        Types.WalletPath memory relayerWalletPath = Types.WalletPath({
            user: orderAddressSet.relayer,
            marketID: 0,
            category: Types.WalletCategory.Balance
        });

        for (uint256 i = 0; i < results.length; i++) {
            transferFrom(
                state,
                orderAddressSet.baseToken,
                results[i].takerWalletPath,
                results[i].makerWalletPath,
                results[i].baseTokenFilledAmount
            );

            settleResult.outputTokenAmount = settleResult.outputTokenAmount.add(results[i].baseTokenFilledAmount);

            uint256 amount = results[i].quoteTokenFilledAmount.
                    add(results[i].makerFee).
                    add(results[i].makerGasFee).
                    sub(results[i].makerRebate);

            transferFrom(
                state,
                orderAddressSet.quoteToken,
                results[i].makerWalletPath,
                relayerWalletPath,
                amount
            );

            totalTakerQuoteTokenFilledAmount = totalTakerQuoteTokenFilledAmount.add(
                results[i].quoteTokenFilledAmount.sub(results[i].takerFee)
            );

            Events.logExchangeMatch(results[i], orderAddressSet);
        }

        transferFrom(
            state,
            orderAddressSet.quoteToken,
            relayerWalletPath,
            results[0].takerWalletPath,
            totalTakerQuoteTokenFilledAmount.sub(results[0].takerGasFee)
        );

        settleResult.incomeTokenAmount = settleResult.incomeTokenAmount.add(totalTakerQuoteTokenFilledAmount.sub(results[0].takerGasFee));
    }

    /**
     * Settles a buy order given a list of Types.MatchResult objects. A naive approach would be to take
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
     * @param results A list of Types.MatchResult objects representing each individual trade to settle.
     * @param orderAddressSet An object containing addresses common across each order.
     */
    function settleTakerBuy(
        Store.State storage state,
        Types.MatchResult[] memory results,
        Types.OrderAddressSet memory orderAddressSet
    )
        internal
        returns (Types.MatchSettleResult memory settleResult)
    {
        settleResult.incomeToken = orderAddressSet.baseToken;
        settleResult.outputToken = orderAddressSet.quoteToken;

        uint256 totalFee = 0;
        Types.WalletPath memory relayerWalletPath = Types.WalletPath({
            user: orderAddressSet.relayer,
            marketID: 0,
            category: Types.WalletCategory.Balance
        });

        for (uint256 i = 0; i < results.length; i++) {
            transferFrom(
                state,
                orderAddressSet.baseToken,
                results[i].makerWalletPath,
                results[i].takerWalletPath,
                results[i].baseTokenFilledAmount
            );

            settleResult.incomeTokenAmount = settleResult.incomeTokenAmount.add(results[i].baseTokenFilledAmount);

            uint256 amount = results[i].quoteTokenFilledAmount.
                    sub(results[i].makerFee).
                    sub(results[i].makerGasFee).
                    add(results[i].makerRebate);

            transferFrom(
                state,
                orderAddressSet.quoteToken,
                results[i].takerWalletPath,
                results[i].makerWalletPath,
                amount
            );

            settleResult.outputTokenAmount = settleResult.outputTokenAmount.add(amount);

            totalFee = totalFee.
                add(results[i].takerFee).
                add(results[i].makerFee).
                add(results[i].makerGasFee).
                add(results[i].takerGasFee).
                sub(results[i].makerRebate);

            Events.logExchangeMatch(results[i], orderAddressSet);
        }

        transferFrom(
            state,
            orderAddressSet.quoteToken,
            results[0].takerWalletPath,
            relayerWalletPath,
            totalFee
        );

        settleResult.outputTokenAmount = settleResult.outputTokenAmount.add(totalFee);
    }

    /**
     */
    function transferFrom(
        Store.State storage state,
        address asset,
        Types.WalletPath memory fromPath,
        Types.WalletPath memory toPath,
        uint256 amount
    )
        internal
    {
        Transfer.transferFrom(state, asset, fromPath, toPath, amount);
    }
}