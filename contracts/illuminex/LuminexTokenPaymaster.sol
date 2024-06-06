// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/* solhint-disable reason-string */
/* solhint-disable no-inline-assembly */

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../core/BasePaymaster.sol";
import "../core/Helpers.sol";
import "../interfaces/IAccountFactory.sol";
import "./LuminexNativeExchange.sol";

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

    using UserOperationLib for UserOperation;

    event AccountDebt(address indexed account, IERC20 indexed token, uint256 debt);

    // TODO calculate cost of postOp
    uint256 constant public COST_OF_POST = 15000;
    mapping(address => mapping(IERC20 => uint256)) public debt;

    constructor(
        IEntryPoint _entryPoint,
        address _owner,
        IERC20 _wrappedNative
    )
    BasePaymaster(_entryPoint)
    LuminexNativeExchange(_owner, _wrappedNative)
    {
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
        (IERC20 token, uint256 maxAllowance) = abi.decode(userOp.paymasterAndData[20 :], (IERC20, uint256));

        uint256 charge = tokensRequiredForNative(token, requiredPreFund) + debt[userOp.sender][token];
        require(charge <= maxAllowance, "IX-TP11 above max pay");

        require(userOp.verificationGasLimit > COST_OF_POST, "IX-TP12 not enough for postOp");

        validationData = 0; // forever
        context = abi.encode(
            userOp.sender,
            token
        );
    }

    function _postOp(PostOpMode, bytes calldata context, uint256 actualGasCost) internal override {
        (address sender, IERC20 token) = abi.decode(context, (address, IERC20));
        uint256 _debt = debt[sender][token];
        uint256 charge = tokensRequiredForNative(token, actualGasCost + COST_OF_POST) + _debt;

        try token.transferFrom(sender, address(this), charge) returns (bool success) {
            if (success)
                charge = 0;
        } catch {}

        _owe(sender, token, charge);
    }

    function _owe(address debtor, IERC20 token, uint256 amount) internal {
        debt[debtor][token] = amount;
        emit AccountDebt(debtor, token, amount);
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
}
