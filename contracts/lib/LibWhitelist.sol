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

pragma solidity ^0.5.8;

import "./LibOwnable.sol";

contract LibWhitelist is LibOwnable {
    mapping (address => bool) public whitelist;
    address[] public allAddresses;

    event AddressAdded(address indexed adr);
    event AddressRemoved(address indexed adr);

    /// @dev Only address in whitelist can invoke functions with this modifier.
    modifier onlyAddressInWhitelist {
        require(whitelist[msg.sender], "SENDER_NOT_IN_WHITELIST_ERROR");
        _;
    }

    /// @dev add Address into whitelist
    /// @param adr Address to add
    function addAddress(address adr) external onlyOwner {
        emit AddressAdded(adr);
        whitelist[adr] = true;
        allAddresses.push(adr);
    }

    /// @dev remove Address from whitelist
    /// @param adr Address to remove
    function removeAddress(address adr) external onlyOwner {
        emit AddressRemoved(adr);
        delete whitelist[adr];
        for(uint i = 0; i < allAddresses.length; i++){
            if(allAddresses[i] == adr) {
                allAddresses[i] = allAddresses[allAddresses.length - 1];
                allAddresses.length -= 1;
                break;
            }
        }
    }

    /// @dev Get all addresses in whitelist
    function getAllAddresses() external view returns (address[] memory) {
        return allAddresses;
    }
}