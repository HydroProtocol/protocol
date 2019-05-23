pragma solidity 0.5.8;

contract Debug {
    event LogBytes32(bytes32);
    event LogUint256(uint256);
    event LogAddress(address);

    uint256 internal updatedTimestamp = 0;

    function getBlockTimestamp() internal view returns (uint256) {
        if (updatedTimestamp > 0) {
            return updatedTimestamp;
        } else {
            return block.timestamp;
        }
    }

    function setBlockTimestamp(uint256 newTimestamp) public {
        updatedTimestamp = newTimestamp;
    }
}