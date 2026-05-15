# FISCO BCOS 合约阶段 1 验证记录

本记录对应 `docs/plans/project-optimization-plan.md` 的“阶段 1：链端可编译”。验证目标是确认 `contracts/fisco-bcos/PersonalInfo.sol`、`Signature.sol` 和 `Table.sol` 能在 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）v3.6.0 环境中编译、部署和调用。

## 验证环境

- Host（主机）：`gstbk-vm`
- System（操作系统）：Ubuntu（Linux 发行版）22.04.4 LTS
- Console（控制台）：`~/fisco/console`
- Node（节点）目录：`~/fisco/nodes/127.0.0.1`
- 验证时间：VM（Virtual Machine，虚拟机）时间 `2026-05-11 04:45` 左右
- 临时运行目录：`/tmp/gstbk-fisco-phase1.8D3XtZ`
- 测试用户标识：`phase1_20260511_044543`

为避免改动 `~/fisco/console/contracts/solidity`，本次把项目合约复制到临时目录：

```bash
scp contracts/fisco-bcos/Table.sol \
    contracts/fisco-bcos/PersonalInfo.sol \
    contracts/fisco-bcos/Signature.sol \
    gstbk-vm:/tmp/gstbk-fisco-phase1.8D3XtZ/contracts/solidity/
```

## Table 接口适配结论

FISCO BCOS v3.6.0 console 附带 `contracts/solidity/Table.sol` 和 `contracts/solidity/TableV320.sol`。本项目 `Table.sol` 是最小接口文件，只声明当前两个业务合约使用的能力：

- `TableManager.createKVTable(string,string,string) returns (int32)`
- `TableManager.openTable(string) view returns (address)`
- `KVTable.get(string) view returns (bool,string)`
- `KVTable.set(string,string) returns (int32)`

上述签名与 console 附带的官方接口一致。`TableV320.sol` 主要扩展了表结构、条件字段和 `descWithKeyOrder`，当前 `PersonalInfo` 与 `Signature` 未使用这些扩展能力，所以本次没有替换项目内的最小 `Table.sol`。

## 编译与部署

部署命令在临时 console 目录执行：

```bash
cd /tmp/gstbk-fisco-phase1.8D3XtZ
./console.sh deploy PersonalInfo
./console.sh deploy Signature
```

| 合约 | 地址 | 部署交易哈希 | 块高 | 状态 |
| --- | --- | --- | --- | --- |
| `PersonalInfo` | `0x4721d1a77e0e76851d460073e64ea06d9c104194` | `0xecaf73af7087a954bfacbe8d78510e418777fc8577f76d89003f7fd36f6843ad` | `2` | `status: 0` |
| `Signature` | `0xc8ead4b26b2c6ac14c9fd90d9684c9bc2cc40085` | `0x88a78ce1d7b1883653b79804e41872b39ec2e059c1ea00dac4b04bba664793c2` | `3` | `status: 0` |

ABI（Application Binary Interface，应用二进制接口）摘要：

```text
select(string) -> (bool,string)
selectWithBlockNumber(string,uint256) -> (int,string)
register(string,string) -> (int)
```

## PersonalInfo 调用验证

测试用户：`phase1_person_20260511_044543`

| 步骤 | 命令摘要 | 交易哈希 / 块高 | 返回结果 |
| --- | --- | --- | --- |
| 初始查询 | `call PersonalInfo <address> select phase1_person_20260511_044543` | 无交易 | `(false, )` |
| 首次注册 | `call PersonalInfo <address> register phase1_person_20260511_044543 info_v1_phase1_20260511_044543` | `0x6d2cc9e102debd45f5ebf5dd63380c646baf3c340349a901f744e1c4880c38d4` / `4` | `(0)` |
| 当前查询 | `call PersonalInfo <address> select phase1_person_20260511_044543` | 无交易 | `(true, info_v1_phase1_20260511_044543)` |
| 历史查询 | `call PersonalInfo <address> selectWithBlockNumber phase1_person_20260511_044543 4` | 无交易 | `(0, info_v1_phase1_20260511_044543)` |
| 重复注册更新 | `call PersonalInfo <address> register phase1_person_20260511_044543 info_v2_phase1_20260511_044543` | `0x5d31352b6722df8ad8b3de8c2da1365f8c1b71ae1e31a619a0b686443e760afc` / `5` | `(0)` |
| 当前查询 | `call PersonalInfo <address> select phase1_person_20260511_044543` | 无交易 | `(true, info_v2_phase1_20260511_044543)` |
| 块高 4 回溯 | `call PersonalInfo <address> selectWithBlockNumber phase1_person_20260511_044543 4` | 无交易 | `(0, info_v1_phase1_20260511_044543)` |
| 块高 5 回溯 | `call PersonalInfo <address> selectWithBlockNumber phase1_person_20260511_044543 5` | 无交易 | `(0, info_v2_phase1_20260511_044543)` |

结论：`PersonalInfo` 首次注册成功，重复注册按合约设计更新当前值，`selectWithBlockNumber` 能按块高查询历史值。

## Signature 调用验证

测试用户：`phase1_signature_20260511_044543`

| 步骤 | 命令摘要 | 交易哈希 / 块高 | 返回结果 |
| --- | --- | --- | --- |
| 初始查询 | `call Signature <address> select phase1_signature_20260511_044543` | 无交易 | `(false, )` |
| 首次注册 | `call Signature <address> register phase1_signature_20260511_044543 signature_v1_phase1_20260511_044543` | `0xc58ce4510950915c9af39db1a171d77cae4f599e67b09783172e778e058cd2bf` / `6` | `(0)` |
| 当前查询 | `call Signature <address> select phase1_signature_20260511_044543` | 无交易 | `(true, signature_v1_phase1_20260511_044543)` |
| 历史查询 | `call Signature <address> selectWithBlockNumber phase1_signature_20260511_044543 6` | 无交易 | `(0, signature_v1_phase1_20260511_044543)` |
| 重复注册 | `call Signature <address> register phase1_signature_20260511_044543 signature_v2_phase1_20260511_044543` | `0x7d3e84355d5cf1026e8dccf7d91718fa9a1633cca6aad843b58414b48bc3ed04` / `7` | `(-1)` |
| 当前查询 | `call Signature <address> select phase1_signature_20260511_044543` | 无交易 | `(true, signature_v1_phase1_20260511_044543)` |
| 块高 7 回溯 | `call Signature <address> selectWithBlockNumber phase1_signature_20260511_044543 7` | 无交易 | `(0, signature_v1_phase1_20260511_044543)` |

结论：`Signature` 首次注册成功，重复注册返回 `-1`，符合“已存在不覆盖”的合约设计；`selectWithBlockNumber` 能从重复注册块高回溯到首次注册签名。

## 验收结论

- `PersonalInfo.sol`、`Signature.sol` 和项目内最小 `Table.sol` 已在 FISCO BCOS v3.6.0 console 中完成编译和部署。
- `register`、`select`、`selectWithBlockNumber` 已按阶段 1 要求验证通过。
- 本次未提交真实证书、私钥、账户文件或 `conf/config.toml`。
- 剩余风险：本次只验证 console 直连调用；Java SDK（Software Development Kit，软件开发工具包）wrapper（包装类）生成和 Rust（系统级编程语言）侧脚本闭环属于阶段 2 和阶段 3。
