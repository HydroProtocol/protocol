pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

library Types {
    struct Asset {
        address tokenAddress;
        uint256 collerateRate;
    }

struct LoanLender {
        address lender;
        uint256 interestRate;
        uint256 amount;
        bytes32 lenderOrderHash;
    }

    struct Loan {
        uint256 id;
        uint256 _type; // pool or p2p
        LoanLender[] lenders;
        address borrower;
        uint256 amount;
        address asset;
        uint256 startAt;
        uint256 expiredAt;
        uint256 averageInterestRate;
    }

    struct CollateralAccount {
        uint256 id;
        address owner;
        uint256 liquidateRate;
        uint256[] loanIDs;
        mapping(address => uint256) collateralAssetAmounts;
    }
}