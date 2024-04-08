// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFeeCalculator {
    function getFeesReceiver(
        IERC20 token,
        uint256 amount
    )
    external
    returns (
        address payable receiver,
        uint256 fee,
        uint256 send
    );
}


