# FISCO BCOS 合约阶段 1 验证记录

阶段 1 验证了 `PersonalInfo.sol`、`Signature.sol` 和 `Table.sol` 在 FISCO BCOS v3.6.0 下的编译、部署和基础调用。以下记录接口适配、复现命令和返回结果。

## Table 接口适配结论

本项目 `Table.sol` 是最小接口文件，只声明当前两个业务合约使用的能力：

- `TableManager.createKVTable(string,string,string) returns (int32)`
- `TableManager.openTable(string) view returns (address)`
- `KVTable.get(string) view returns (bool,string)`
- `KVTable.set(string,string) returns (int32)`

上述签名与 FISCO BCOS v3.6.0 console 附带的官方接口一致。`TableV320.sol` 的扩展能力当前未被 `PersonalInfo` 与 `Signature` 使用。

## 验证路径

在目标 FISCO BCOS console 环境中复制合约后执行：

```bash
./console.sh deploy PersonalInfo
./console.sh deploy Signature
```

ABI 摘要：

```text
select(string) -> (bool,string)
selectWithBlockNumber(string,uint256) -> (int,string)
register(string,string) -> (int)
```

## PersonalInfo 调用结论

- 初始 `select <user>` 返回不存在。
- 首次 `register <user> <info>` 返回 `0`。
- 当前 `select <user>` 返回 `exists true` 和写入的 info。
- `selectWithBlockNumber <user> <registerBlock>` 返回 `ret 0` 和历史值。
- 重复 `register` 会更新当前值，并可按块高回溯旧值。

## Signature 调用结论

- 初始 `select <user>` 返回不存在。
- 首次 `register <user> <signature>` 返回 `0`。
- 当前 `select <user>` 返回 `exists true` 和写入的 signature。
- `selectWithBlockNumber <user> <registerBlock>` 返回 `ret 0` 和历史值。
- 重复 `register` 返回 `-1`，符合“已存在不覆盖”的合约设计。

## 验收结论

- `PersonalInfo.sol`、`Signature.sol` 和项目内最小 `Table.sol` 可在 FISCO BCOS v3.6.0 console 中完成编译和部署。
- `register`、`select`、`selectWithBlockNumber` 已按阶段 1 要求验证通过。
- Java SDK 包装类生成和 Rust 调用联调见 [fisco-java-sdk-stage2.md](fisco-java-sdk-stage2.md)。
