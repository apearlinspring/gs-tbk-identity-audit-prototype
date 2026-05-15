# FISCO BCOS 合约

本目录保存链端 Solidity（智能合约编程语言）材料，用于补齐 Rust（系统级编程语言）侧调用的 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）链上存储部分。

## 合约

- `PersonalInfo.sol`：身份隐私数据表合约，表名 `u_info`，用于登记、更新和按块高查询用户身份密文/证明材料。
- `Signature.sol`：用户签名表合约，表名 `u_signatures`，用于登记和查询用户签名 JSON（JavaScript Object Notation，数据交换格式）。
- `Table.sol`：项目内最小接口文件，声明 `TableManager` 与 `KVTable`，匹配 `PersonalInfo.sol` 和 `Signature.sol` 当前用到的 FISCO BCOS KVTable（键值表）预编译合约能力。

## 版本注意

两个业务合约使用 `TableManager(address(0x1002))` 和 `KVTable`。这类接口主要对应 FISCO BCOS 的 KV 存储预编译合约；如果实际链版本升级或启用不同存储接口，应以官方 `Table.sol` / SDK（Software Development Kit，软件开发工具包）生成文件为准。

## Rust 侧关系

- `crates/user` 在签名阶段把用户签名写入链端 `Signature` 合约。
- `crates/user` 在身份字段阶段把个人信息密文写入链端 `PersonalInfo` 合约。
- `crates/node` 在验证阶段从链端读取签名数据，完成 Verify（验证）和 Open（揭示）流程。
