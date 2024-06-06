// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

interface ILuminexComplianceManager {
    function record(address target, uint256 value, bytes memory data) external;
}
