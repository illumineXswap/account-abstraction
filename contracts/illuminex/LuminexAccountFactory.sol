// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IAccountFactory.sol";
import "../interfaces/ISealedEncryptor.sol";
import "../interfaces/ILuminexAllowedCalls.sol";
import "../interfaces/IEntryPoint.sol";

import "./LuminexAccount.sol";
import "./RotatingKeys.sol";
import "./LuminexAccountComplianceManager.sol";

/* solhint-disable avoid-low-level-calls */

/**
 * A sample factory contract for LuminexAccount.sol
 * A UserOperations "initCode" holds the address of the factory, and a method call (to createAccount, in this sample factory).
 * The factory's createAccount returns the target account address even if it is already installed.
 * This way, the entryPoint.getSenderAddress() can be called either before or after the account is created.
 */
contract LuminexAccountFactory is IAccountFactory, ILuminexAllowedCalls, ISealedEncryptor, RotatingKeys, AccessControl, Ownable {

    bytes32 public constant BALANCE_VIEWER = keccak256("ix:BALANCE_VIEWER");
    bytes32 public constant CALL_MANAGER = keccak256("ix:CALL_MANAGER");

    LuminexAccount public immutable accountImplementation;

    mapping(address => bool) private _deployedAccounts;

    LuminexAccountComplianceManager public complianceManager;

    event CallsAllowed(address indexed target, bytes4[] selectors);
    event CallsDisallowed(address indexed target, bytes4[] selectors);

    mapping(address => mapping(bytes4 => bool)) public allowedCalls;

    constructor(address _owner, IEntryPoint _entryPoint)
    RotatingKeys(keccak256(abi.encodePacked(block.number)), type(LuminexAccountFactory).name)
    {
        accountImplementation = new LuminexAccount(_entryPoint, this, complianceManager);

        _transferOwnership(_owner);

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _setRoleAdmin(BALANCE_VIEWER, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(CALL_MANAGER, DEFAULT_ADMIN_ROLE);
    }

    function setComplianceManager(LuminexAccountComplianceManager _manager) public onlyOwner() {
        complianceManager = _manager;
    }

    function allowCalls(address target, bytes4[] calldata selectors) public onlyRole(CALL_MANAGER) {
        for (uint i; i < selectors.length; i++) {
            allowedCalls[target][selectors[i]] = true;
        }

        emit CallsAllowed(target, selectors);
    }

    function disallowCalls(address target, bytes4[] calldata selectors) public onlyRole(CALL_MANAGER) {
        for (uint i; i < selectors.length; i++) {
            delete allowedCalls[target][selectors[i]];
        }

        emit CallsDisallowed(target, selectors);
    }

    function isCallAllowed(address target, bytes memory callData) public view returns (bool allowed) {
        bytes4 selector = bytes4(callData);
        return allowedCalls[target][selector];
    }

    function balanceOf(IERC20 token, address account) public view onlyRole(BALANCE_VIEWER) returns (uint256) {
        require(_deployedAccounts[account], "IX-AF20 Not deployed");

        return LuminexAccount(payable(account)).factoryBalanceOf(token);
    }

    /**
     * create an account, and return its address.
     * returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
     */
    function createAccount(address accountOwner, bytes32 salt) public returns (LuminexAccount ret) {
        address addr = getAddress(accountOwner, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return LuminexAccount(payable(addr));
        }

        ERC1967Proxy _proxy = new ERC1967Proxy{salt: salt}(
            address(accountImplementation),
            abi.encodeCall(LuminexAccount.initialize, (accountOwner))
        );
        ret = LuminexAccount(payable(_proxy));

        _deployedAccounts[address(_proxy)] = true;

        _updateRingKey(keccak256(abi.encodePacked(
            block.number,
            accountOwner,
            salt,
            address(_proxy)
        )));
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(address accountOwner, bytes32 salt) public view returns (address) {
        return Create2.computeAddress(bytes32(salt), keccak256(abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(
                address(accountImplementation),
                abi.encodeCall(LuminexAccount.initialize, (accountOwner))
            )
        )));
    }

    function encryptFor(address _receiver, bytes memory _payload) public view returns (bytes memory encrypted) {
        (bytes memory _encrypted, uint256 _keyIndex) = _encryptPayload(_payload);

        encrypted = abi.encode(
            keccak256(abi.encodePacked(
                _keyIndex,
                _receiver,
                _payload
            )),
            _keyIndex,
            _encrypted
        );
    }

    function decryptForMe(bytes calldata _encrypted) public view returns (bytes memory payload) {
        (
            bytes32 _expectedHash,
            uint256 _keyIndex,
            bytes memory _encryptedPayload
        ) = abi.decode(_encrypted, (bytes32, uint256, bytes));

        payload = _decryptPayload(
            _keyIndex,
            _encryptedPayload
        );

        bytes32 _realHash = keccak256(abi.encodePacked(
            _keyIndex,
            msg.sender,
            payload
        ));
        require(_expectedHash == _realHash, "IX-AF10 Wrong receiver");
    }

    function deployedAccounts(address _account) public view returns (bool created) {
        created = _deployedAccounts[_account];
    }
}


