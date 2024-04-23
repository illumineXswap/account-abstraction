// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract LuminexFeeCalculator is Ownable {

    struct FeeConfig {
        uint256 flat;
        uint112 proportionalNumerator;
        uint112 proportionalDenominator;
    }

    mapping(IERC20 => FeeConfig) public feeConfigs;

    event FeeConfigSet(IERC20 indexed token, FeeConfig config);
    event FeeConfigUnset(IERC20 indexed token);


    function setFee(IERC20 token, FeeConfig calldata config) public onlyOwner {
        require(config.proportionalDenominator > 0, "Denominator should at least be 1");

        feeConfigs[token] = config;
        emit FeeConfigSet(token, config);
    }

    function unsetFee(IERC20 token) public onlyOwner {
        delete feeConfigs[token];
        emit FeeConfigUnset(token);
    }

    function getTokenValueOfGas(
        IERC20 token,
        uint256 amount
    )
    public
    view
    returns (
        uint256 value
    ){
        FeeConfig memory _feeConfig = feeConfigs[token];
        require(_feeConfig.proportionalDenominator > 0, "IX-FC1 Token not supported");

        uint256 _proportionalFee = amount * _feeConfig.proportionalNumerator / _feeConfig.proportionalDenominator;
        value = _proportionalFee + _feeConfig.flat;
    }
}
