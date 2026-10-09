// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.10 <0.8.20;
pragma experimental ABIEncoderV2;

import "./Table.sol";

contract PersonalInfo {
    // event
    event RegisterEvent(
        int256 ret,
        string indexed user,
        string indexed info
    );
    event UpdateEvent(
        string user,
        string info,
        string key
    );
    
    KVTable kvTable;
    TableManager tm;
    string constant tableName = "u_info";

    constructor() {
    	// 构造函数中创建u_info表
        tm = TableManager(address(0x1002));
        tm.createKVTable(tableName, "user", "info");
        address t_address = tm.openTable(tableName);
        kvTable = KVTable(t_address);
    }

    /*
    描述 : 根据用户查询对应信息
    参数 ：
            user : 用户

    返回值：
            参数一： 成功返回0, 用户不存在返回-1
            参数二： 第一个参数为0时有效，用户信息
    */
    function select(string memory user) 
    public 
    view 
    returns (bool, string memory) 
    {
        // 查询
        bool result;
        string memory value;
        (result, value) = kvTable.get(user);
        return (result, value);
    }

/*
    描述 : 查询用户信息历史状态
    参数 ：
            user : 资产账户
            block_number : 块高

    返回值：
            参数一： 成功返回0, 用户不存在返回-1, 块高状态查询失败返回-2
            参数二： 第一个参数为0时有效，信息
    */
    function selectWithBlockNumber(string memory user, uint256 block_number) 
    public 
    view 
    returns (int256, string memory) 
    {
        bool ret;
        string memory temp_value;
        // 查询账号是否存在
        (ret, temp_value) = select(user);
        if (ret != true) {
            return (-1, uint2str(0));
        }

        // 查找 [1, block_number]
        uint256 low = 1;
        uint256 high = block_number;
        while(low < high) {
            string memory key = string(abi.encodePacked(user, "@", uint2str(high)));
            string memory info;
            // 查询账号是否存在
            (ret, info) = select(key);
            if (ret) {
                return (0, info);
            }
            high = high - 1;
        }

        return (-2, uint2str(0));
    }

    /*
    描述 : 更新用户历史状态
    参数 ：
            user : 用户
            block_number: 块高
            info: 信息

    返回值：
            无
    */
    function update(string memory user, uint256 block_number, string memory info) 
    private 
    {
        string memory key = string(abi.encodePacked(user, "@", uint2str(block_number)));
        kvTable.set(key, info);
        emit UpdateEvent(user, info, key);
    }

    /*
    描述 : 用户信息注册
    参数 ：
            user : 用户
            info  : 信息
    返回值：
            0  成功
            -1 失败
    */
    function register(string memory user, string memory info)
    public
    returns (int256)
    {
        int256 ret_code = 0;
        bool ret = true;
        string memory temp_value;
        // 查询账号是否存在
        (ret, temp_value) = select(user);
        if (ret != true) {
            // 不存在，创建并插入
            int32 count = kvTable.set(user, info);
            if (count == 1) {
                // 成功
                ret_code = 0;
                // 更新历史状态
                update(user, block.number, info);
            } else {
                // 失败? 无权限或者其他错误
                ret_code = - 2;
            }
        } else {
            // 账户已存在, 直接更新数据
            // ret_code = - 1;
            kvTable.set(user,info);
            // 更新历史状态
            update(user, block.number, info);
        }

        emit RegisterEvent(ret_code, user, info);

        return ret_code;
    }
    
    function uint2str(uint256 _i)
    internal
    pure
    returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}

