pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "../lib/Types.sol";

interface BorrowingSourceInterface {
    /**
     * Borrow Asset
     *
     * @param  asset           Address of the borrowing asset
     * @param  amount          Amount of the total borrowing asset
     * @param  maxInterestRate The worst interest rate (ARP) to take
     * @param  data            Extra data
     * @return                 Loans
     */
    function borrow(address asset, uint256 amount, uint256 maxInterestRate, bytes calldata data) external returns (Types.Loan memory);

    /**
     * Repay debt with interest
     *
     * @param  loanID          ID of the loan you are going to repay
     * @param  amount          Amount of repayment (not include interest)
     * @return                 Success or not
     */
    function repayLoan(uint256 loanID, uint256 amount) external payable returns (bool);

    /**
     * Repay the last amount of debt and won't have any repay in the feature.
     *
     * @param  loanID          ID of the loan you are going to repay
     * @param  amount          Amount of last left repayment (not include interest)
     * @return                 Success or not
     */
    function breakLoan(uint256 loanID, uint256 amount) external payable returns (bool);
}