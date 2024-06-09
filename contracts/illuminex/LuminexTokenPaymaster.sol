// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/* solhint-disable reason-string */
/* solhint-disable no-inline-assembly */

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../core/BasePaymaster.sol";
import "../core/Helpers.sol";
import "../interfaces/IAccountFactory.sol";
import "./LuminexNativeExchange.sol";
import "./LuminexAccountFactory.sol";

/**
 * A sample paymaster that uses external service to decide whether to pay for the UserOp.
 * The paymaster trusts an external signer to sign the transaction.
 * The calling user must pass the UserOp to that external signer first, which performs
 * whatever off-chain verification before signing the UserOp.
 * Note that this signature is NOT a replacement for the account-specific signature:
 * - the paymaster checks a signature to agree to PAY for GAS.
 * - the account checks a signature to prove identity and account ownership.
 */
contract LuminexTokenPaymaster is BasePaymaster, LuminexNativeExchange {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;

    event AccountDebt(IERC20 indexed token, uint256 debt);

    // TODO calculate cost of postOp
    uint256 constant public COST_OF_POST = 15000;
    mapping(address => mapping(IERC20 => uint256)) public debt;
    LuminexAccountFactory public immutable accountFactory;

    mapping(address => bool) public trustedSigners;

    uint256 private constant VALID_TIMESTAMP_OFFSET = 20;
    // TODO double check offset in bytes
    uint256 private constant SIGNATURE_OFFSET =
        VALID_TIMESTAMP_OFFSET + 
        6 + 6 + // validUntil + validAfter
        20 + // ERC20 token
        32; // maxAllowance
    
    constructor(
        IEntryPoint _entryPoint,
        address _owner,
        IERC20 _wrappedNative,
        LuminexAccountFactory _accountFactory
    )
    BasePaymaster(_entryPoint)
    LuminexNativeExchange(_owner, _wrappedNative)
    {
        accountFactory = _accountFactory;
    }

    function _isValidBuyer(address _buyer) internal view virtual override returns (bool) {
        return accountFactory.deployedAccounts(_buyer);
    }

    /**
     * verify our external signer signed this request.
     * the "paymasterAndData" is expected to be the paymaster and a signature over the entire request params
     * paymasterAndData[:20] : address(this)
     * paymasterAndData[20:] : abi.encode(tokenAddress, maxAllowance)
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 requiredPreFund
    )
    internal
    view
    override
    returns (bytes memory context, uint256 validationData)
    {
        (uint48 validUntil, uint48 validAfter, IERC20 token, uint256 maxAllowance, bytes calldata signature) = parsePaymasterAndData(userOp.paymasterAndData);

        uint256 charge = tokensRequiredForNative(token, requiredPreFund) + debt[userOp.sender][token];
        require(charge <= accountFactory.balanceOf(token, userOp.sender), "IX-TP10 Not enough balance");
        require(charge <= maxAllowance, "IX-TP11 above max allowance");

        require(userOp.verificationGasLimit > COST_OF_POST, "IX-TP12 not enough for postOp");
    
        require(signature.length == 64 || signature.length == 65, "IX-TP13 invalid signature length in paymasterAndData");

        bytes32 hash = ECDSA.toEthSignedMessageHash(getHash(userOp, validUntil, validAfter, token, maxAllowance));

        bool signatureValid = trustedSigners[ECDSA.recover(hash, signature)];

        validationData = _packValidationData(
            !signatureValid,
            validUntil,
            validAfter
        );
        context = abi.encode(
            userOp.sender,
            token
        );
    }

    function _postOp(PostOpMode opMode, bytes calldata context, uint256 actualGasCost) internal override {
        (address sender, IERC20 token) = abi.decode(context, (address, IERC20));
        uint256 _debt = debt[sender][token];
        uint256 charge = tokensRequiredForNative(token, actualGasCost + COST_OF_POST) + _debt;

        if (opMode != PostOpMode.postOpReverted) {
            token.safeTransferFrom(sender, address(this), charge);
            charge = 0;
        }

        _owe(sender, token, charge);
    }

    function _owe(address debtor, IERC20 token, uint256 amount) internal {
        if (debt[debtor][token] == amount) return;
        debt[debtor][token] = amount;
        emit AccountDebt(token, amount);
    }

    function payDebt(address debtor, IERC20 token) public {
        uint256 _debt = debt[debtor][token];
        token.safeTransferFrom(_msgSender(), address(this), _debt);
        _owe(debtor, token, 0);
    }

    function skim(address payable to) public onlyOwner {
        to.transfer(address(this).balance);
    }

    function skim(IERC20 token, address payable to) public onlyOwner {
        token.safeTransfer(to, token.balanceOf(address(this)));
    }

    function parsePaymasterAndData(bytes calldata paymasterAndData) public pure returns(uint48 validUntil, uint48 validAfter, IERC20 token, uint256 maxAllowance, bytes calldata signature) {
        (validUntil, validAfter, token, maxAllowance) = abi.decode(
            paymasterAndData[VALID_TIMESTAMP_OFFSET:SIGNATURE_OFFSET],
            (uint48, uint48, IERC20, uint256)
        );
        signature = paymasterAndData[SIGNATURE_OFFSET:];
    }


    function pack(UserOperation calldata userOp) internal pure returns (bytes memory ret) {
        // lighter signature scheme. must match UserOp.ts#packUserOp
        bytes calldata pnd = userOp.paymasterAndData;
        // copy directly the userOp from calldata up to (but not including) the paymasterAndData.
        // this encoding depends on the ABI encoding of calldata, but is much lighter to copy
        // than referencing each field separately.
        assembly {
            let ofs := userOp
            let len := sub(sub(pnd.offset, ofs), 32)
            ret := mload(0x40)
            mstore(0x40, add(ret, add(len, 32)))
            mstore(ret, len)
            calldatacopy(add(ret, 32), ofs, len)
        }
    }


    /**
     * return the hash we're going to sign off-chain (and validate on-chain)
     * this method is called by the off-chain service, to sign the request.
     * it is called on-chain from the validatePaymasterUserOp, to validate the signature.
     * note that this signature covers all fields of the UserOperation, except the "paymasterAndData",
     * which will carry the signature itself.
     */
    function getHash(UserOperation calldata userOp, uint48 validUntil, uint48 validAfter, IERC20 token, uint256 maxAllowance)
    public view returns (bytes32) {
        //can't use userOp.hash(), since it contains also the paymasterAndData itself.

        return keccak256(abi.encode(
                pack(userOp),
                block.chainid,
                address(this),
                validUntil,
                validAfter,
                token,
                maxAllowance
            ));
    }

    function setSignerTrust(address signer, bool trust) public onlyOwner() {
        if (trust)
            trustedSigners[signer] = true;
        else
            delete trustedSigners[signer];
    }
}
