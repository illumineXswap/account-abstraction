// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./LuminexOracle.sol";

abstract contract LuminexNativeExchange is Ownable {
    using SafeERC20 for IERC20;

    address public beneficiary;
    mapping(IERC20 => LuminexOracle) public oracles;
    IERC20 public immutable WRAPPED_NATIVE;


    event OracleSet(IERC20 indexed token, LuminexOracle oracle);
    event BeneficiarySet(address beneficiary);

    constructor(address _owner, IERC20 _native) {
        _transferOwnership(_owner);
        _setBeneficiary(_owner);
        WRAPPED_NATIVE = _native;
    }

    receive() external payable {}

    function _setBeneficiary(address newBeneficiary) internal {
        beneficiary = newBeneficiary;
        emit BeneficiarySet(newBeneficiary);
    }

    function setBeneficiary(address newBeneficiary) public onlyOwner {
        _setBeneficiary(newBeneficiary);
    }

    function setOracle(IERC20 token, LuminexOracle oracle) public onlyOwner {
        require(oracle.token0() == WRAPPED_NATIVE, "IX-EX20 token0 should be WRAPPED_NATIVE");
        require(oracle.token1() == token, "IX-EX21 token1 does not match");
        oracles[token] = oracle;
        emit OracleSet(token, oracle);
    }

    function _isValidBuyer(address _buyer) internal view virtual returns (bool);

    function buyNativeForToken(IERC20 _token, uint256 tokenValue, uint256 minNative, address payable receiver) public {
        require(_isValidBuyer(msg.sender), "Invalid buyer");

        LuminexOracle oracle = oracles[_token];
        require(address(oracle) != address(0), "IX-EX10 Token not supported");
        require(address(this).balance >= minNative, "IX-EX11 Not enough liquidity");

        uint256 nativeValue = oracle.token0WorthOfToken1(tokenValue);
        require(nativeValue >= minNative, "IX-EX12 Native price too high");

        _token.safeTransferFrom(_msgSender(), beneficiary, tokenValue);

        (bool sent,) = receiver.call{value: nativeValue}("");
        require(sent, "IX-EX14 Failed to send");
    }

    function tokensRequiredForNative(IERC20 _token, uint256 _minNative) public view returns (uint256 _tokenRequired) {
        LuminexOracle oracle = oracles[_token];
        require(address(oracle) != address(0), "IX-EX30 Token not supported");

        _tokenRequired = oracle.token1WorthOfToken0(_minNative);
    }
}
