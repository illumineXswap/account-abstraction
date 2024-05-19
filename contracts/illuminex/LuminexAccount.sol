// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "../core/BaseAccount.sol";
import "../core/Helpers.sol";
import "../interfaces/ISealedEncryptor.sol";

/**
  * minimal account.
  *  this is sample minimal account.
  *  has execute, eth handling methods
  *  has a single signer that can send requests through the entryPoint.
  */
contract LuminexAccount is BaseAccount, UUPSUpgradeable, Initializable {
    address public owner;
    uint256 constant internal SIG_VALIDATION_SUCCESS = 0;

    using SafeERC20 for IERC20;
    using UserOperationLib for UserOperation;
    using ECDSA for bytes32;

    IEntryPoint private immutable _entryPoint;
    ISealedEncryptor private immutable _encryption;

    event SimpleAccountInitialized(IEntryPoint indexed entryPoint, address indexed owner);

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor(IEntryPoint anEntryPoint, ISealedEncryptor anEncryptor) {
        _entryPoint = anEntryPoint;
        _encryption = anEncryptor;
        _disableInitializers();
    }

    function _onlyOwner() internal view {
        //directly from EOA owner, or through the account itself (which gets redirected through execute())
        require(msg.sender == owner || msg.sender == address(this), "IX-AA11 only owner");
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     * @param dest destination address to call
     * @param value the value to pass in this call
     * @param func the calldata to pass in this call
     */
    function execute(address dest, uint256 value, bytes calldata func) external onlyTrusted {
        _call(dest, value, func);
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     * @param encryptedCall encrypted call data
     */
    function executeEncrypted(bytes calldata encryptedCall) external onlyTrusted {
        (address dest, uint256 value, bytes memory func) = abi.decode(
            _encryption.decryptForMe(encryptedCall),
            (address, uint256, bytes)
        );
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
     * @param dest an array of destination addresses
     * @param value an array of values to pass to each call. can be zero-length for no-value calls
     * @param func an array of calldata to pass to each call
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func) external onlyTrusted {
        require(dest.length == func.length && (value.length == 0 || value.length == func.length), "wrong array lengths");
        if (value.length == 0) {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], 0, func[i]);
            }
        } else {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], value[i], func[i]);
            }
        }
    }

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of LuminexAccount.sol must be deployed with the new EntryPoint address, then upgrading
     * the implementation by calling `upgradeTo()`
     * @param anOwner the owner (signer) of this account
     */
    function initialize(address anOwner) public virtual initializer {
        _initialize(anOwner);
    }

    function _initialize(address anOwner) internal virtual {
        owner = anOwner;

        emit SimpleAccountInitialized(_entryPoint, owner);
    }

    modifier onlyTrusted() {
        _requireFromEntryPointOrOwnerOrSelf();
        _;
    }

    // Require the function call went through EntryPoint or owner
    function _requireFromEntryPointOrOwnerOrSelf() internal view {
        require(
            msg.sender == address(entryPoint()) ||
            msg.sender == owner ||
            msg.sender == address(this),
            "IX-AA10 no Owner nor EntryPoint"
        );
    }

    /// implement template method of BaseAccount
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal override virtual returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        // NOTE:
        // We raise error instead of returning SIG_VALIDATION_FAILED so that even simulation can't leak anything
        // without user approval.
        // require(owner == ECDSA.recover(hash, userOp.signature), "IX-AA20 denied");
        if (owner == ECDSA.recover(hash, userOp.signature))
            return SIG_VALIDATION_SUCCESS;
        else
            return SIG_VALIDATION_FAILED;
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function callAndReturn(address target, uint256 value, bytes memory data) external onlyTrusted() returns (bytes memory) {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        return result;
    }

    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function _authorizeUpgrade(address) internal view override {
        _onlyOwner();
    }
}

