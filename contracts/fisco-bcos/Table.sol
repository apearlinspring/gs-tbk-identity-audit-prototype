// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.10 <0.8.20;

interface KVTable {
    function get(string memory key) external view returns (bool, string memory);
    function set(string memory key, string memory value) external returns (int32);
}

interface TableManager {
    function createKVTable(
        string memory tableName,
        string memory keyField,
        string memory valueField
    ) external returns (int32);

    function openTable(string memory tableName) external view returns (address);
}
