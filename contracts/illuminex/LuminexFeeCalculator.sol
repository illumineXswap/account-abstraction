// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IFeeCalculator.sol";

abstract contract LuminexFeeCalculator is IFeeCalculator, Ownable {

    struct FeeConfig {
        address payable collector;
        uint256 flat;
        uint112 proportionalNumerator;
        uint112 proportionalDenominator;
    }

    mapping(IERC20 => FeeConfig) public feeConfigs;

    event FeeConfigSet(IERC20 indexed token, FeeConfig config);
    event FeeConfigUnset(IERC20 indexed token);


    function setFee(IERC20 token, FeeConfig calldata config) public onlyOwner {
        require(config.proportionalDenominator > 0, "Denominator should at least be 1");
        require(config.collector != address(0), "Collector should be set");

        feeConfigs[token] = config;
        emit FeeConfigSet(token, config);
    }

    function unsetFee(IERC20 token) public onlyOwner {
        delete feeConfigs[token];
        emit FeeConfigUnset(token);
    }

    function getFeesReceiver(
        IERC20 token,
        uint256 amount
    )
    public
    view
    returns (
        address payable receiver,
        uint256 fee,
        uint256 send
    ){
        FeeConfig memory _feeConfig = feeConfigs[token];
        receiver = _feeConfig.collector;
        require(receiver != address(0), "IX-FC1 Token not supported");

        uint256 _proportionalFee = amount * _feeConfig.proportionalNumerator / _feeConfig.proportionalDenominator;
        fee = _proportionalFee + _feeConfig.flat;
        send = amount - fee;

        require(send > 0, "IX-FC2 Amount is not enough");
    }
}
