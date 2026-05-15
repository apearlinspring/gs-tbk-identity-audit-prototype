# 恶意用户 Verify（验证）/Open（揭示）摘要

本报告由 `scripts/evidence/run-malicious-open-demo.sh` 从 E2E（End-to-End，端到端）Manifest（运行清单）和角色日志生成。脚本只读本地文件，不连接 FISCO BCOS（金融区块链合作联盟开源区块链底层平台），也不需要真实证书、账户或配置。

## 运行来源

| 字段 | 值 |
| --- | --- |
| Manifest | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json` |
| 日志目录 | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z` |
| 输出目录 | `/tmp/gstbk-live-malicious-open-20260512T153825Z` |
| E2E 成功 | true |
| 命令 | `/tmp/gstbk-vm-bootstrap-e2e-report-verify/scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-e2e-vm-smoke --reuse-chain --contract-addresses-from-env --timeout-seconds 300` |

## demo（演示）用户

| Manifest 用户 | 协议用户编号 | 链上用户名 | 签名入口 | 判读角色 |
| --- | --- | --- | --- | --- |
| user1 | 1 | e2e20260512T153825Z_user1 | sign_wrong | 恶意演示目标 |
| user2 | 2 | e2e20260512T153825Z_user2 | sign | 正常对照用户 |

## 链上证据

| Manifest 用户 | 链上用户名 | 合约 | TX（Transaction，交易）哈希 | 区块 | ret | select exists | select 日志 | select SHA-256 | 身份密文 SHA-256 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| user1 | e2e20260512T153825Z_user1 | Signature | `0x6241dbee06f3de44c1f8090549e7e835ba8c7d7bf7c529251370e98da2396edb` | 51 | 0 | true | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/chain/user1-signature-select.out` | `9cedc46f02b647bb55dd82aa890ec37d2f1296aebf3075dd486bde86818a02e0` | - |
| user1 | e2e20260512T153825Z_user1 | PersonalInfo | `0xfc5613668bf381f3bd0d9b939688a909148ceddf612906c9f1a23d9ac6c6c907` | 53 | 0 | true | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/chain/user1-info-select.out` | `3909269f93e10c9433327f3528710cc0caa2cf2c9c6aad65a765faeb8048528a` | `ee45a06a599c74455f614ecfaee121afdf669b921507747e48b547ccf83c2b29` |
| user2 | e2e20260512T153825Z_user2 | Signature | `0xfceab5a2c4927e908499d4a517f6c5d1fe9c3f62d2bb3c6c9e3e81d19169ff23` | 52 | 0 | true | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/chain/user2-signature-select.out` | `bdb029094f004f4d132fac756ba9a96f266a4df510f5919ca05295e7d9ba7efc` | - |
| user2 | e2e20260512T153825Z_user2 | PersonalInfo | `0x9b52c5c553b00196223b36ea70fb9b9c5d583ec1053d24e60ea2b87da4dcacd9` | 54 | 0 | true | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/chain/user2-info-select.out` | `b28c8040e81166e9bb3722f2430f9ffefb6be0c201ca1c44b7c16fdbb04ece64` | `5d5085dbf9bf92c65660b7419c86e19ecab490acacec19ba762301300c01fa3d` |

## Verify/Open 日志摘录

| 链上用户名 | Node（管理员节点） | 日志路径 | 日志 SHA-256 | Signature 查询 | Verify 结果 | Open 状态 | 揭示摘录 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| e2e20260512T153825Z_user1 | node1 | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node1.out` | `50a6cbf2772f5323ef766467da0206ccb388268f3a848b695382ce8e83595a16` | exists true | 失败，触发 Open | 完成 | 未捕获信息级揭示行；本次真实日志保留 Verify 失败和 Open 完成 |
| e2e20260512T153825Z_user1 | node2 | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node2.out` | `50a6cbf2772f5323ef766467da0206ccb388268f3a848b695382ce8e83595a16` | exists true | 失败，触发 Open | 完成 | 未捕获信息级揭示行；本次真实日志保留 Verify 失败和 Open 完成 |
| e2e20260512T153825Z_user1 | node3 | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node3.out` | `5d0df5eca6e5d27e6c3967bfab14dfcb3635aef7e9cb2125d258e4ab142065d2` | exists true | 失败，触发 Open | 完成 | 未捕获信息级揭示行；本次真实日志保留 Verify 失败和 Open 完成 |
| e2e20260512T153825Z_user1 | node4 | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node4.out` | `50a6cbf2772f5323ef766467da0206ccb388268f3a848b695382ce8e83595a16` | exists true | 失败，触发 Open | 完成 | 未捕获信息级揭示行；本次真实日志保留 Verify 失败和 Open 完成 |
| e2e20260512T153825Z_user2 | node1 | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node1.out` | `50a6cbf2772f5323ef766467da0206ccb388268f3a848b695382ce8e83595a16` | exists true | 通过 | 全局完成，非本用户触发 | - |
| e2e20260512T153825Z_user2 | node2 | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node2.out` | `50a6cbf2772f5323ef766467da0206ccb388268f3a848b695382ce8e83595a16` | exists true | 通过 | 全局完成，非本用户触发 | - |
| e2e20260512T153825Z_user2 | node3 | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node3.out` | `5d0df5eca6e5d27e6c3967bfab14dfcb3635aef7e9cb2125d258e4ab142065d2` | exists true | 通过 | 全局完成，非本用户触发 | - |
| e2e20260512T153825Z_user2 | node4 | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node4.out` | `50a6cbf2772f5323ef766467da0206ccb388268f3a848b695382ce8e83595a16` | exists true | 通过 | 全局完成，非本用户触发 | - |

## 判读口径

- `Signature 查询` 为 `exists true` 表示 Node 已从链上取到签名 JSON（JavaScript Object Notation，数据交换格式）。
- `Verify 结果` 为 `失败，触发 Open` 表示本地签名校验失败，随后进入 Open（揭示）。
- `揭示摘录` 出现 `maybe malicious`、`user_id`、`user_name` 和 `user address` 时，可以把匿名签名定位回具体用户。
- `揭示摘录` 显示未捕获信息级揭示行时，表示本次真实 VM 角色日志只保留了 Verify 失败和 Open 完成等 stdout（标准输出）信号；身份定位仍以 manifest（运行清单）中的 demo 用户映射和后续开启信息级日志的运行结果复核。
- `Open 状态` 为 `全局完成，非本用户触发` 时，表示同一轮 Node 日志中存在其他用户触发的 Open 阶段，但当前用户 Verify 已通过。
