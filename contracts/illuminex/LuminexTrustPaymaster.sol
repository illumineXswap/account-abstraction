// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/* solhint-disable reason-string */
/* solhint-disable no-inline-assembly */

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../core/BasePaymaster.sol";
import "../core/UserOperationLib.sol";
import "../core/Helpers.sol";
import "../interfaces/IAccountFactory.sol";

/**
 * A sample paymaster that uses external service to decide whether to pay for the UserOp.
 * The paymaster trusts an external signer to sign the transaction.
 * The calling user must pass the UserOp to that external signer first, which performs
 * whatever off-chain verification before signing the UserOp.
 * Note that this signature is NOT a replacement for the account-specific signature:
 * - the paymaster checks a signature to agree to PAY for GAS.
 * - the account checks a signature to prove identity and account ownership.
 */
contract LuminexTrustPaymaster is BasePaymaster {
    using SafeERC20 for ERC20;

    using UserOperationLib for PackedUserOperation;

    mapping(address => bool) public trustedAccountFactories;

    event TrustAccountFactory(address indexed factory);
    event DistrustAccountFactory(address indexed factory);

    bytes private constant EMPTY_CONTEXT = "";
    uint256 private constant VALID_TIMESTAMP_OFFSET = PAYMASTER_DATA_OFFSET;
    uint256 private constant ACCOUNT_FACTORY_OFFSET = VALID_TIMESTAMP_OFFSET + 64;

    constructor(
        IEntryPoint _entryPoint
    ) BasePaymaster(_entryPoint) {}

    /**
     * verify our external signer signed this request.
     * the "paymasterAndData" is expected to be the paymaster and a signature over the entire request params
     * paymasterAndData[:20] : address(this)
     * paymasterAndData[20:84] : abi.encode(validUntil, validAfter)
     * paymasterAndData[84:] : signature
     */
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 /*requiredPreFund*/
    )
    internal
    view
    override
    returns (bytes memory context, uint256 validationData)
    {
        (uint48 validUntil, uint48 validAfter) = abi.decode(
            userOp.paymasterAndData[VALID_TIMESTAMP_OFFSET :],
            (uint48, uint48)
        );

        address _accountFactory = address(0);

        if (userOp.paymasterAndData.length == ACCOUNT_FACTORY_OFFSET + 20) {
            (_accountFactory) = abi.decode(userOp.paymasterAndData[ACCOUNT_FACTORY_OFFSET :], (address));
        }


        bool _validationFailed = (
            _accountFactory == address(0) ||
            !trustedAccountFactories[_accountFactory] ||
            !IAccountFactory(_accountFactory).deployedAccounts(userOp.sender)
        );

        return (EMPTY_CONTEXT, _packValidationData(_validationFailed, validUntil, validAfter));
    }

    function trustAccountFactory(address factory) public onlyOwner {
        trustedAccountFactories[factory] = true;
        emit TrustAccountFactory(factory);
    }

    function distrustAccountFactory(address factory) public onlyOwner {
        trustedAccountFactories[factory] = false;
        emit DistrustAccountFactory(factory);
    }

    function skim(address payable to) public onlyOwner {
        to.transfer(address(this).balance);
    }

    function skim(ERC20 token, address payable to) public onlyOwner {
        token.safeTransfer(to, token.balanceOf(address(this)));
    }
}
