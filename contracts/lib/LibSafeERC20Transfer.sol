pragma solidity 0.5.8;

contract LibSafeERC20Transfer {
    function safeTransfer(address token, address to, uint256 amount) internal {

        // mute warning
        to;
        amount;

        assembly {
            let tmp1 := mload(0)
            let tmp2 := mload(4)
            let tmp3 := mload(36)

            // keccak256('transfer(address,uint256)') & 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
            mstore(0, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)

            // calldatacopy(t, f, s) copy s bytes from calldata at position f to mem at position t
            // copy from, to, value from calldata to memory
            calldatacopy(4, 36, 64)

            // call ERC20 Token contract transfer function
            let result := call(gas, token, 0, 0, 68, 0, 32)

            mstore(0, tmp1)
            mstore(4, tmp2)
            mstore(36, tmp3)

            // Some ERC20 Token contract doesn't return any value when calling the transfer function successfully.
            // So we consider the transfer call is successful in either case below.
            //   1. call successfully and nothing return.
            //   2. call successfully, return value is 32 bytes long and the value isn't equal to zero.
            switch eq(result, 1)
            case 1 {
                switch or(eq(returndatasize, 0), and(eq(returndatasize, 32), gt(mload(0), 0)))
                case 1 {
                    return(0, 0)
                }
            }
        }

        revert("TOKEN_TRANSFER_ERROR");
    }

    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {

        // mute warning
        from;
        to;
        amount;

        assembly {
            let tmp1 := mload(0)
            let tmp2 := mload(4)
            let tmp3 := mload(36)
            let tmp4 := mload(68)

            // keccak256('transferFrom(address,address,uint256)') & 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
            mstore(0, 0x23b872dd00000000000000000000000000000000000000000000000000000000)

            // calldatacopy(t, f, s) copy s bytes from calldata at position f to mem at position t
            // copy from, to, value from calldata to memory
            calldatacopy(4, 36, 96)

            // call ERC20 Token contract transferFrom function
            let result := call(gas, token, 0, 0, 100, 0, 32)

            mstore(0, tmp1)
            mstore(4, tmp2)
            mstore(36, tmp3)
            mstore(68, tmp4)

            // Some ERC20 Token contract doesn't return any value when calling the transferFrom function successfully.
            // So we consider the transferFrom call is successful in either case below.
            //   1. call successfully and nothing return.
            //   2. call successfully, return value is 32 bytes long and the value isn't equal to zero.
            switch eq(result, 1)
            case 1 {
                switch or(eq(returndatasize, 0), and(eq(returndatasize, 32), gt(mload(0), 0)))
                case 1 {
                    return(0, 0)
                }
            }
        }

        revert("TOKEN_TRANSFER_FROM_ERROR");
    }
}