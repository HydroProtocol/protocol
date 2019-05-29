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

import "./funding/Assets.sol";
import "./funding/Orders.sol";
import "./funding/Loans.sol";
import "./funding/Auctions.sol";
import "./funding/CollateralAccounts.sol";

import "./helper/Debug.sol";

contract Funding is Debug, Orders, Auctions, CollateralAccounts {

    mapping(address => uint256) inLiquidation;

    constructor(address _proxyAddress, address _oracleAddress)
        public
    {}

    function matchOrders(
        Order memory takerOrder,
        Order[] memory makerOrders,
        uint256[] memory filledAmounts
    ) public {

    //     require(isOrderValid(takerOrder));
        require(makerOrders.length == filledAmounts.length, "MAKER_ORDERS_AND_FILLED_AMOUNTS_MISMATCH");

        for (uint256 i = 0; i < makerOrders.length; i++) {

            Order memory makerOrder = makerOrders[i];
    //         require(isOrderValid(makerOrder));

            if (isLenderOrder(makerOrder.data)) {
                matchSingleOrderInternal(
                    makerOrder,
                    takerOrder,
                    filledAmounts[i],
                    getOrderInterestRate(makerOrder.data)
                );
            } else {
                matchSingleOrderInternal(
                    takerOrder,
                    makerOrder,
                    filledAmounts[i],
                    getOrderInterestRate(makerOrder.data)
                );
            }
        }
    }

    function matchSingleOrderInternal(
        Order memory lenderOrder,
        Order memory borrowerOrder,
        uint256 amount,
        uint256 executeInterest
    ) internal {
        address borrower = borrowerOrder.owner;
        address lender = lenderOrder.owner;

        require(borrower != lender, "CAN_NOT_MATCH_SAME_USER_ORDERS");

        // check asset
        require(lenderOrder.asset == borrowerOrder.asset, "ASSET_MISMATCH");

        // check relayer
        require(lenderOrder.relayer == borrowerOrder.relayer, "RELAYER_MISMATCH");
        require(msg.sender == lenderOrder.relayer, "INVALID_SENDER"); // use sender logic

        // check executeInterest
        // require(executeInterest >= getInterestRate(lenderOrder));
        // require(executeInterest <= getInterestRate(borrowerOrder));

        // check amount
        bytes32 borrowerOrderHash = getOrderHash(borrowerOrder);
        // require(amount <= borrowerOrder.amount - orderInfos[borrowerOrderId].filledAmount);
        bytes32 lenderOrderHash = getOrderHash(lenderOrder);
        // require(amount <= lenderOrder.amount - orderInfos[lenderOrderId].filledAmount);

        // check loan duration
        uint40 lenderDuration;
        // if (block.timestamp + getLoanDuration(lenderOrder) < getExpiredAt(lenderOrder)){
        //     lenderDuration = getLoanDuration(lenderOrder);
        // } else {
        //     lenderDuration = getExpiredAt(lenderOrder) - block.timestamp;
        // }
        // require(lenderDuration >= getLoanDuration(borrowerOrder));

        // new loan
        Loan memory newLoan = Loan(
            0,
            lenderOrderHash,
            lenderOrder.owner,
            borrowerOrder.owner,
            borrowerOrder.relayer,
            lenderOrder.asset,
            amount,
            uint16(executeInterest),
            uint40(getBlockTimestamp()),
            lenderDuration,
            getOrderFeeRate(lenderOrder.data),
            0
        );

        uint256 id = createLoan(newLoan);

        findOrCreateDefaultCollateralAccount(borrowerOrder.owner).loanIDs.push(id);

        // TODO use a match result
        // settle loan, transfer asset,
        transferFrom(borrowerOrder.asset, lenderOrder.owner, borrowerOrder.owner, amount);

        // change filled amount
        orderFilledAmount[borrowerOrderHash] = orderFilledAmount[borrowerOrderHash].add(amount);
        orderFilledAmount[lenderOrderHash] = orderFilledAmount[lenderOrderHash].add(amount);

    //     // borrower
    //     require(isUserRepayable(borrower));
    }

    // function cancel(Order memory order) {
    //     require(msg.sender == order.owner);
    //     bytes32 orderId = hashOrder(order);
    //     orderInfos[orderId].canceled = true;
    // }

    // function repay(bytes32 loanId, uint256 amount) {
    //     Loan memory loan = loansById[loanId];

    //     // must be sent by borrower
    //     require(msg.sender == loan.borrower);

    //     // require amount less than loan amount
    //     require(amount <= loan.amount);

    //     // calculate interest
    //     (uint256 totalInterest, uint256 relayerFee) = calculateLoanInterest(loanId, amount);
    //     uint256 lenderInterest = totalInterest - relayerFee;

    //     // settle assets
    //     vault.transferCash(loan.asset, loan.borrower, loan.lender, amount+lenderInterest);
    //     vault.transferCash(loan.asset, loan.borrower, loan.relayer, relayerFee);

    //     // change loan info
    //     reduceLoan(loanId, amount);
    // }

    function repayLoanPublic(uint256 loanID, uint256 amount) public {
        Loan memory loan = allLoans[loanID];
        repayLoan(loan, msg.sender, amount);
    }

    function claimAuction(uint256 id) public {
        Auction memory auction = allAuctions[id];
        Loan memory loan = allLoans[auction.loanID];
        claimAuctionWithAmount(id, loan.amount);
    }

    function claimAuctionWithAmount(uint256 id, uint256 repayAmount) public {
        Auction storage auction = allAuctions[id];
        Loan memory loan = allLoans[auction.loanID];
        uint256 loanLeftAmount = loan.amount;

        // pay debt
        repayLoan(loan, msg.sender, repayAmount);

        uint256 ratio = getAuctionRatio(auction);

        CollateralAccount storage account = findOrCreateDefaultCollateralAccount(loan.borrower);

        // receive assets
        for (uint256 i = 0; i < allAssets.length; i++) {
            Asset memory asset = allAssets[i];

            if (auction.assetAmounts[i] == 0) {
                continue;
            }

            uint256 amount = auction.assetAmounts[i].mul(ratio).mul(repayAmount).div(loanLeftAmount.mul(100));
            auction.assetAmounts[i] = auction.assetAmounts[i].sub(amount);

            withdrawLiquidatedAssetsToProxy(asset.tokenAddress, msg.sender, amount);

            if (loan.amount == 0 && auction.assetAmounts[i] > 0) {
                liquidatingAssets[asset.tokenAddress] = liquidatingAssets[asset.tokenAddress].sub(auction.assetAmounts[i]);
                account.assetAmounts[asset.tokenAddress] = account.assetAmounts[asset.tokenAddress].add(auction.assetAmounts[i]);
                auction.assetAmounts[i] = 0;
            }
        }

        emit AuctionClaimed(id, repayAmount);

        if (loan.amount == 0) {
            delete allAuctions[id];

            emit AuctionFinished(id);
        }
    }

    function withdrawLiquidatedAssetsToProxy(address token, address to, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        // TODO separate by user ??
        liquidatingAssets[token] = liquidatingAssets[token].sub(amount);

        if (token == address(0)) {
            depositEthFor(to, amount);
        } else {
            if (EIP20Interface(token).allowance(address(this), proxyAddress) < amount) {
                EIP20Interface(token).approve(proxyAddress, 0xf0000000000000000000000000000000000000000000000000000000000000);
            }
            depositTokenFor(token, to, amount);
        }

        emit WithdrawCollateral(token, to, amount);
    }
}