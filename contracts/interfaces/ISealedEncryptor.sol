// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ISealedEncryptor {
    function encryptFor(address _receiver, bytes memory _payload) external returns (bytes memory encrypted);

    function decryptForMe(bytes calldata _encrypted) external returns (bytes memory payload);
}
