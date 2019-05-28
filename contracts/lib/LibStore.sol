pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "./Types.sol";

library LibStore {
    struct State {
        // collateral count
        uint256 collateralAccountCount;

        // a map to save all Margin collateral accounts
        mapping(uint256 => Types.CollateralAccount) allCollateralAccounts;

        // a map to save all funding collateral accounts
        mapping(address => uint256) userDefaultCollateralAccounts;

        uint256 assetsCount;

        mapping(uint256 => Types.Asset) assets;

        uint256 loansCount;

        //
        mapping(uint256 => Types.Loan) allLoans;

        //
        mapping(address => uint256[]) loansByBorrower;

        // asset balances (free to use money)
        mapping (address => mapping (address => uint)) balances;
    }
}