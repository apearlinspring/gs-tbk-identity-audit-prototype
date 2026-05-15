# 恶意用户 Verify（验证）/Open（揭示）摘要

本报告由 `scripts/evidence/run-malicious-open-demo.sh` 从 E2E（End-to-End，端到端）Manifest（运行清单）和角色 stdout（标准输出）/log4rs（Rust 日志框架）日志生成。脚本只读本地文件，不连接 FISCO BCOS（金融区块链合作联盟开源区块链底层平台），也不需要真实证书、账户或配置。

## 运行来源

| 字段 | 值 |
| --- | --- |
| Manifest | `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/manifest.json` |
| 日志目录 | `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z` |
| 输出目录 | `/tmp/gstbk-open-reveal-log-capture-summary-20260512T200205Z` |
| E2E 成功 | true |
| 命令 | `scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-open-reveal-log-capture-runtime --reuse-chain --contract-addresses-from-env --timeout-seconds 300` |

## demo（演示）用户

| Manifest 用户 | 协议用户编号 | 链上用户名 | 签名入口 | 判读角色 |
| --- | --- | --- | --- | --- |
| user1 | 1 | e2e20260512T200205Z_user1 | sign_wrong | 恶意演示目标 |
| user2 | 2 | e2e20260512T200205Z_user2 | sign | 正常对照用户 |

## 链上证据

| Manifest 用户 | 链上用户名 | 合约 | TX（Transaction，交易）哈希 | 区块 | ret | select exists | select 日志 | select SHA-256 | 身份密文 SHA-256 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| user1 | e2e20260512T200205Z_user1 | Signature | `0x40f8638e14b51b08f026d0b2269889f8b19ec9ac8c39356173922502e46b51ae` | 55 | 0 | true | `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/chain/user1-signature-select.out` | `7d43d8db46f4fd09e29bd3748d3864d22775e809d0e33109be0c58d9c6eab981` | - |
| user1 | e2e20260512T200205Z_user1 | PersonalInfo | `0x756e9c5725a063610463cb535f55fae4a26885be938c61fdf82e994f4f65ce81` | 57 | 0 | true | `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/chain/user1-info-select.out` | `00a01551d103d5ba3c3d4930ebc22d9179055d707619276afdfd80447af1008c` | `ced9e132af6c2d014cc2e105b93fa23c35857ea33d6a61f2e0570463c1d9e208` |
| user2 | e2e20260512T200205Z_user2 | Signature | `0x5c83248fe9f3d39f3f804765414d7db1ea0f9e224ded7c04cc728b5ef939507d` | 56 | 0 | true | `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/chain/user2-signature-select.out` | `a0933b2159aea597ce12d00257e8c7581e01210793ce17a8a33f6cc02edc054a` | - |
| user2 | e2e20260512T200205Z_user2 | PersonalInfo | `0x389370ddfa8d7ef400a7608fa9d2de565192e99a09e7e0d19c94b0715e0bf64b` | 58 | 0 | true | `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/chain/user2-info-select.out` | `dd6b39e477fa3722ecc5b280c9c970e9fde3783ea110c60e83a2093d9715b1fe` | `d07c56af5437bc9b66d6cccb5806947abc5bc9ea72c359c3d4aa82b3f98ba8c1` |

## Verify/Open 日志摘录

| 链上用户名 | Node（管理员节点） | 日志路径 | 日志 SHA-256 | Signature 查询 | Verify 结果 | Open 状态 | 揭示摘录 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| e2e20260512T200205Z_user1 | node1 | stdout: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node1.out`<br>log4rs_file: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node1.log4rs.log` | stdout: `e2ad67a511b794f4e33ea5541907afc6a9f636cb654c2e000859651fcabfaf82`<br>log4rs_file: `25e8ddd248ab1429cbbea4ddef8d93cb6935b16f3be75e739e065bbc96a0077f` | exists true | 失败，触发 Open | 完成 | This user 1 maybe used a invaild key!<br>This user 1 maybe malicious!<br>user_id:1<br>user_name:e2e20260512T200205Z_user1<br>user address:"127.0.0.1:60001" |
| e2e20260512T200205Z_user1 | node2 | stdout: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node2.out`<br>log4rs_file: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node2.log4rs.log` | stdout: `e2ad67a511b794f4e33ea5541907afc6a9f636cb654c2e000859651fcabfaf82`<br>log4rs_file: `cdda8adeb121e00cca3d607c377f5b63e9f9b8220034a4444c1d6e35642bb938` | exists true | 失败，触发 Open | 完成 | This user 1 maybe used a invaild key!<br>This user 1 maybe malicious!<br>user_id:1<br>user_name:e2e20260512T200205Z_user1<br>user address:"127.0.0.1:60001" |
| e2e20260512T200205Z_user1 | node3 | stdout: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node3.out`<br>log4rs_file: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node3.log4rs.log` | stdout: `e2ad67a511b794f4e33ea5541907afc6a9f636cb654c2e000859651fcabfaf82`<br>log4rs_file: `fe48fc6d9c4e025b0d35fce3842b8cbc930bcfe104bd4120ddb37efaa0452be7` | exists true | 失败，触发 Open | 完成 | This user 1 maybe used a invaild key!<br>This user 1 maybe malicious!<br>user_id:1<br>user_name:e2e20260512T200205Z_user1<br>user address:"127.0.0.1:60001" |
| e2e20260512T200205Z_user1 | node4 | stdout: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node4.out`<br>log4rs_file: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node4.log4rs.log` | stdout: `5a56bdcf4ce061a49139748a7f2f616a2fc21f7dbef9ea82205f1924e8c4642d`<br>log4rs_file: `28a5566c6ab4443cf086a17b9468b962bec4992baecdae3e97cf401322cba8a0` | exists true | 失败，触发 Open | 完成 | This user 1 maybe used a invaild key!<br>This user 1 maybe malicious!<br>user_id:1<br>user_name:e2e20260512T200205Z_user1<br>user address:"127.0.0.1:60001" |
| e2e20260512T200205Z_user2 | node1 | stdout: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node1.out`<br>log4rs_file: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node1.log4rs.log` | stdout: `e2ad67a511b794f4e33ea5541907afc6a9f636cb654c2e000859651fcabfaf82`<br>log4rs_file: `25e8ddd248ab1429cbbea4ddef8d93cb6935b16f3be75e739e065bbc96a0077f` | exists true | 通过 | 全局完成，非本用户触发 | - |
| e2e20260512T200205Z_user2 | node2 | stdout: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node2.out`<br>log4rs_file: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node2.log4rs.log` | stdout: `e2ad67a511b794f4e33ea5541907afc6a9f636cb654c2e000859651fcabfaf82`<br>log4rs_file: `cdda8adeb121e00cca3d607c377f5b63e9f9b8220034a4444c1d6e35642bb938` | exists true | 通过 | 全局完成，非本用户触发 | - |
| e2e20260512T200205Z_user2 | node3 | stdout: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node3.out`<br>log4rs_file: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node3.log4rs.log` | stdout: `e2ad67a511b794f4e33ea5541907afc6a9f636cb654c2e000859651fcabfaf82`<br>log4rs_file: `fe48fc6d9c4e025b0d35fce3842b8cbc930bcfe104bd4120ddb37efaa0452be7` | exists true | 通过 | 全局完成，非本用户触发 | - |
| e2e20260512T200205Z_user2 | node4 | stdout: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node4.out`<br>log4rs_file: `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/node4.log4rs.log` | stdout: `5a56bdcf4ce061a49139748a7f2f616a2fc21f7dbef9ea82205f1924e8c4642d`<br>log4rs_file: `28a5566c6ab4443cf086a17b9468b962bec4992baecdae3e97cf401322cba8a0` | exists true | 通过 | 全局完成，非本用户触发 | - |

## 判读口径

- `Signature 查询` 为 `exists true` 表示 Node 已从链上取到签名 JSON（JavaScript Object Notation，数据交换格式）。
- `Verify 结果` 为 `失败，触发 Open` 表示本地签名校验失败，随后进入 Open（揭示）。
- `揭示摘录` 出现 `maybe malicious`、`user_id`、`user_name` 和 `user address` 时，可以把匿名签名定位回具体用户。
- `揭示摘录` 显示未捕获信息级揭示行时，表示当前 manifest（运行清单）可读取的角色日志来源中仍没有 `info!` 信息级揭示行；应先确认 E2E（End-to-End，端到端）运行是否已收集 Node 的 log4rs（Rust 日志框架）文件日志。
