// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LuminexOracle.sol";

contract LuminexOracleConst is LuminexOracle, Ownable {
    uint256 private _token0Value;
    uint256 private _token1Value;

    event ValuesSet(uint256 _value0, uint256 _value1);

    constructor(address _owner, IERC20 _token0, IERC20 _token1) {
        _transferOwnership(_owner);
        token0 = _token0;
        token1 = _token1;
    }

    function setValues(uint256 _value0, uint256 _value1) public onlyOwner {
        require(_value0 * _value1 != 0, "IX-CO10 neither of values can be 0");

        _token0Value = _value0;
        _token1Value = _value1;
        emit ValuesSet(_value0, _value1);
    }

    function token0Value() public override view returns (uint256) {
        return _token0Value;
    }

    function token1Value() public override view returns (uint256) {
        return _token1Value;
    }
}
