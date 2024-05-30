// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract LuminexOracle {

    IERC20 public token0;
    IERC20 public token1;

    function token0Value() public virtual view returns (uint256);

    function token1Value() public virtual view returns (uint256);

    function token0WorthOfToken1(
        uint256 token1Amount
    )
    public
    virtual
    view
    returns (
        uint256 token0Amount
    ){
        token0Amount = token1Amount * token0Value() / token1Value();
    }

    function token1WorthOfToken0(
        uint256 token0Amount
    )
    public
    virtual
    view
    returns (
        uint256 token1Amount
    ){
        token1Amount = token0Amount * token1Value() / token0Value();
    }
}
