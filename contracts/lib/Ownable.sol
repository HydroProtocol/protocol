/*

    Copyright 2019 The Hydro Protocol Foundation

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

pragma solidity ^0.5.8;

/**
 * Library to handle user permissions.
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /** @dev The Ownable constructor sets the original `owner` of the contract to the sender account. */
    constructor()
        internal
    {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /** @return the address of the owner. */
    function owner()
        public
        view
        returns(address)
    {
        return _owner;
    }

    /** @dev Throws if called by any account other than the owner. */
    modifier onlyOwner() {
        require(isOwner(), "NOT_OWNER");
        _;
    }

    /** @return true if `msg.sender` is the owner of the contract. */
    function isOwner()
        public
        view
        returns(bool)
    {
        return msg.sender == _owner;
    }

    /** @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership()
        public
        onlyOwner
    {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /** @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(
        address newOwner
    )
        public
        onlyOwner
    {
        require(newOwner != address(0), "INVALID_OWNER");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}