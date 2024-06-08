// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ILuminexAllowedCalls {
    function isCallAllowed(address target, bytes memory callData) external returns (bool allowed);
}
