pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "../lib/Types.sol";

interface CollateralAccountInterface {
    /**
     * Create a collateralAccount
     *
     * @param  asset           Address of the borrowing asset
     * @param  amount          Amount of the total borrowing asset
     * @param  maxInterestRate The worst interest rate (ARP) to take
     * @param  data            Extra data
     * @return                 Loans
     */
    function createAccount(address owner, Types.Loan memory loan) external returns (Types.Loan memory);

    /**
     * Create a collateralAccount
     *
     * @param  asset           Address of the borrowing asset
     * @param  amount          Amount of the total borrowing asset
     * @param  maxInterestRate The worst interest rate (ARP) to take
     * @param  data            Extra data
     * @return                 Loans
     */
    function addLoanToAccount(uint256 accountID, Types.Loan memory loan) external returns (Types.Loan memory);
}