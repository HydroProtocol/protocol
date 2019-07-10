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

pragma solidity 0.5.8;

import "../lib/Store.sol";
import "../lib/Events.sol";

/**
 * @title Relayer provides two distinct features for relayers.
 *
 * First, Relayers can opt into or out of the Hydro liquidity incentive system.
 * Second, a relayer can register a delegate address.
 * Delegates can send matching requests on behalf of relayers.
 * The delegate scheme allows additional possibilities for smart contract interaction.
 * on behalf of the relayer.
 */
library Relayer {
    /**
     * Approve an address to match orders on behalf of msg.sender
     */
    function approveDelegate(
        Store.State storage state,
        address delegate
    )
        internal
    {
        state.relayer.relayerDelegates[msg.sender][delegate] = true;
        Events.logRelayerApproveDelegate(msg.sender, delegate);
    }

    /**
     * Revoke an existing delegate
     */
    function revokeDelegate(
        Store.State storage state,
        address delegate
    )
        internal
    {
        state.relayer.relayerDelegates[msg.sender][delegate] = false;
        Events.logRelayerRevokeDelegate(msg.sender, delegate);
    }

    /**
     * @return true if msg.sender is allowed to match orders which belong to relayer
     */
    function canMatchOrdersFrom(
        Store.State storage state,
        address relayer
    )
        internal
        view
        returns(bool)
    {
        return msg.sender == relayer || state.relayer.relayerDelegates[relayer][msg.sender] == true;
    }

    /**
     * Join the Hydro incentive system.
     */
    function joinIncentiveSystem(
        Store.State storage state
    )
        internal
    {
        delete state.relayer.hasExited[msg.sender];
        Events.logRelayerJoin(msg.sender);
    }

    /**
     * Exit the Hydro incentive system.
     * For relayers that choose to opt-out, the Hydro Protocol
     * effective becomes a tokenless protocol.
     */
    function exitIncentiveSystem(
        Store.State storage state
    )
        internal
    {
        state.relayer.hasExited[msg.sender] = true;
        Events.logRelayerExit(msg.sender);
    }

    /**
     * @return true if relayer is participating in the Hydro incentive system.
     */
    function isParticipant(
        Store.State storage state,
        address relayer
    )
        internal
        view
        returns(bool)
    {
        return !state.relayer.hasExited[relayer];
    }
}