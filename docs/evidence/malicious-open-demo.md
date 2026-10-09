# 恶意用户 Verify/Open Demo

演示使用异常签名触发 Verify 失败，随后由多个 Node 协作完成 Open。摘要脚本从已有 E2E 的 manifest 和角色日志提取结果。

## 流程

User 把签名 JSON 写入 `Signature` 合约。Node 查回签名，用群公钥和用户加入材料执行 Verify。校验失败时，多个 Node 提交 Open 份额，由 Proxy 聚合，再由 Node 对照本地注册表定位协议用户。

## 演示设置

- 当前角色入口里 `user1` 在收到 Revoke 广播后调用 `sign_wrong`，用于模拟恶意或异常签名；`user2` 调用正常 `sign`，作为对照用户。
- Verify 阶段通过 `GSTBK_SIGNATURE_APP_DIR/signature_run.sh select <user>` 查询链上 `Signature` 记录，再反序列化签名 JSON 做校验。
- Open 阶段只在 Verify 失败后触发；Proxy 聚合 Node 的 Open 份额，Node 再把聚合结果和本地注册表对照，输出被揭示用户。
- 身份字段的 CL 密文和证明保存在 `PersonalInfo` 合约中，摘要展示对应的上链记录。Open 不会自动调用监管者解密真实身份字段。

## 角色入口

| 角色 | 当前行为 | 证据入口 |
| --- | --- | --- |
| `user1` | 收到 Revoke 广播后执行 `sign_wrong("rolldragon")`，模拟恶意签名 | `crates/intergration_test/src/user/user1/user1.rs` |
| `user2` | 收到同一阶段广播后执行正常 `sign("rolldragon")`，作为对照用户 | `crates/intergration_test/src/user/user2/user2.rs` |
| Node | Verify 阶段先查链上 `Signature`，再校验签名；失败时发送 Open phase one 消息 | `crates/node/src/gs_tbk_scheme/verify_phase.rs` |
| Proxy | 收齐 Node 的 Open phase one / phase two 消息后广播聚合结果 | `crates/proxy/src/gs_tbk_scheme/open_phase.rs` |
| Node | Open phase three 将聚合结果与本地注册表对照并输出揭示结果 | `crates/node/src/gs_tbk_scheme/open_phase.rs` |

## 摘要脚本

`scripts/evidence/run-malicious-open-demo.sh` 从已有 manifest 和角色日志生成摘要，无需重新连接链端。

```bash
bash scripts/evidence/run-malicious-open-demo.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json \
  --output-dir /tmp/gstbk-malicious-open-summary
```

只查看异常签名用户：

```bash
bash scripts/evidence/run-malicious-open-demo.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json \
  --user user1
```

输出文件包含：

- 演示用户与签名入口：`user1 -> sign_wrong`、`user2 -> sign`。
- `Signature` / `PersonalInfo` 的交易哈希、区块、`ret`、`select exists` 和身份密文 SHA-256。
- 每个 Node 日志里的 `Signature query`、Verify 结果、Open 状态和揭示摘录。

## 结果说明

- 链上签名记录包含用户编号和名称等元数据，身份字段密文另存于 `PersonalInfo`；演示不提供端到端匿名性。
- 监管触发时，Node 从链上查回签名并做 Verify；如果签名异常，多个 Node 通过 Open 份额协作，让 Proxy 聚合中间值，再由 Node 对照本地注册表揭示协议用户。
- `Signature` 与 `PersonalInfo` 的 TX 哈希、区块高度、`select exists true`、历史查询和身份密文 SHA-256，把“签名输入、验证失败、Open 输出、身份密文上链记录”连成可复核证据链。
