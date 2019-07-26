pragma solidity 0.5.8;

/**
 * Get USD price of asset,
 * The return value is the USD value of the 10**18 lowest units of the asset.
 *
 * For example, Ether has a 18 decimals, so the price is for each Ether.
 * But for a token has 10 decimals, the price is for 10**8 tokens.
 */
interface IPriceOracle {
    /** return USD price of token */
    function getPrice(
        address asset
    )
        external
        view
        returns (uint256);
}