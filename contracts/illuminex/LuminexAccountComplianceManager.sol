// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IAccountFactory.sol";
import "../interfaces/ILuminexComplianceManager.sol";

contract LuminexAccountComplianceManager is Ownable, ILuminexComplianceManager {
    struct ComplianceRecord {
        address sender;
        address target;
        bytes data;
        uint256 timestamp;
        uint256 value;
    }

    ComplianceRecord[] private _records;
    mapping(address => uint256[]) private _recordsIdsBySender;

    mapping(address => uint256[]) private _revealedEntriesByAddress;

    address public complianceManager;

    IAccountFactory public immutable accountsFactory;

    event ComplianceManagerChange(address newManager);
    event Reveal(address indexed sender, uint256 recordsCount);

    modifier onlyAccount() {
        require(accountsFactory.deployedAccounts(msg.sender), "Not a smart account");
        _;
    }

    modifier onlyComplianceManager() {
        require(msg.sender == complianceManager);
        _;
    }

    constructor(address _accountsFactory) {
        accountsFactory = IAccountFactory(_accountsFactory);
    }

    function setComplianceManager(address _newManager) public onlyOwner {
        complianceManager = _newManager;
        emit ComplianceManagerChange(_newManager);
    }

    function record(address target, uint256 value, bytes memory data) public override onlyAccount {
        uint256 _id = _records.length;
        _records.push(ComplianceRecord(msg.sender, target, data, block.timestamp, value));
        _recordsIdsBySender[msg.sender].push(_id);
    }

    function fetchRevealed(address sender, uint256 from, uint256 to)
        public
        view onlyComplianceManager
        returns (ComplianceRecord[] memory)
    {
        ComplianceRecord[] memory _slice = new ComplianceRecord[](to - from);

        for (uint i = from; i < to; i++) {
            _slice[i - from] = _records[_revealedEntriesByAddress[sender][i]];
        }

        return _slice;
    }

    function reveal(address sender, uint256 recordsCount) public onlyComplianceManager {
        require(_revealedEntriesByAddress[sender].length + recordsCount <= _recordsIdsBySender[sender].length, "Too much");
        emit Reveal(sender, recordsCount);

        uint256 _len = _revealedEntriesByAddress[sender].length;
        for (uint i = _len; i < _len + recordsCount; i++) {
            _revealedEntriesByAddress[sender].push(_recordsIdsBySender[sender][i]);
        }
    }
}
