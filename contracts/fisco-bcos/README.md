# FISCO BCOS 合约

两个业务合约负责存储身份密文和签名记录，Rust 通过 Java SDK 调用它们。

- `PersonalInfo.sol`：表名 `u_info`，登记、更新身份密文和证明材料，并按区块高度查询历史快照。
- `Signature.sol`：表名 `u_signatures`，登记和查询用户签名 JSON。
- `Table.sol`：声明这两个合约所需的 `TableManager` 和 `KVTable` 接口。

合约使用 `TableManager(address(0x1002))` 和 `KVTable`。升级链版本或存储接口时，需要一并核对 `Table.sol` 和 SDK 生成文件。

## Rust 调用

User 在签名阶段登记签名和身份密文；Node 从链上读取签名，随后在 Rust 中执行 Verify/Open。合约负责记录与查询，密码学验证在链下完成。

编译、部署和包装类生成方式见[FISCO 运行手册](../../docs/operations/fisco-runbook.md)。
