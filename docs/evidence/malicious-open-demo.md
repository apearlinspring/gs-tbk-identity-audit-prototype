# 恶意用户 Verify（验证）/Open（揭示） demo（演示）

本文对应 `feat/malicious-open-demo`，目标是把现有 Verify/Open 流程整理成面试可讲、证据可查的恶意用户揭示链路。本文只复用现有 E2E（End-to-End，端到端）报告、角色入口、链上记录和可读取日志，不修改 GS-TBK（Group Signatures with Time-bound Keys，带时间绑定密钥的群签名方案）密码学协议，不提交真实证书、私钥、账户、wallet（钱包）、keystore（密钥库）、`conf/config.toml` 或 runtime（运行时）状态。

## 一句话链路

匿名 User（用户）先把签名 JSON（JavaScript Object Notation，数据交换格式）写入 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）的 `Signature` 合约；Node（管理员节点）从链上查回签名后用本地群公钥和用户加入材料做 Verify；当恶意签名校验失败时，多个 Node 把 Open 份额交给 Proxy（代理）聚合，再由 Node 将匿名签名定位回 `user_id`、`user_name` 和用户地址；链上 TX（Transaction，交易）哈希、区块高度、`select exists true` 和身份密文 SHA-256（安全哈希算法 256 位）用于审计复核。

## 当前 demo 边界

- 当前角色入口里 `user1` 在收到 Revoke（撤销）广播后调用 `sign_wrong`，用于模拟恶意或异常签名；`user2` 调用正常 `sign`，作为对照用户。
- Verify 阶段不直接信任本地临时文件，而是通过 `GSTBK_SIGNATURE_APP_DIR/signature_run.sh select <user>` 查询链上 `Signature` 记录，再反序列化签名 JSON 做校验。
- Open 阶段只在 Verify 失败后触发；Proxy 聚合 Node 的 Open 份额，Node 再把聚合结果和本地注册表 `reg` 对照，输出被揭示用户。
- 身份字段 CL（Castagnos-Laguillaumie，同态加密方案）密文和 ZKP（Zero-Knowledge Proof，零知识证明）材料仍走 `PersonalInfo` 合约，本文只把它作为“被揭示用户身份材料已上链且可审计”的旁证，不展开监管者解密流程。

## 证据基线

本文以 2026-05-12 真实 VM（Virtual Machine，虚拟机）E2E 正式报告为主证据：

- 报告：`docs/evidence/e2e-report-20260512T153825Z.md`
- Manifest（运行清单）：`/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json`
- 源码快照：`/tmp/gstbk-vm-bootstrap-e2e-report-verify`
- E2E 命令：`bash scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-e2e-vm-smoke --reuse-chain --contract-addresses-from-env --timeout-seconds 300`
- 区块高度：运行前 `50`，运行后 `54`
- 角色结果：Proxy 与 4 个 Node 完成 KeyGen（联合密钥生成）；Proxy 完成 Revoke；2 个 User 完成 Join（用户加入）和 Sign（签名）；4 个 Node 查询 `Signature` 返回 `exists true` 并完成 Open；2 个 User 均完成 `Signature` 与 `PersonalInfo` register（登记）。

## 角色入口证据

| 角色 | 当前行为 | 证据入口 |
| --- | --- | --- |
| `user1` | 收到 `ProxyToUserRevokePhaseBroadcastMsg` 后执行 `sign_wrong("rolldragon")`，模拟恶意签名 | `crates/intergration_test/src/user/user1/user1.rs` |
| `user2` | 收到同一阶段广播后执行正常 `sign("rolldragon")`，作为对照用户 | `crates/intergration_test/src/user/user2/user2.rs` |
| Node | Verify 阶段先查链上 `Signature`，再校验签名；失败时发送 `NodeToProxyOpenPhaseOneP2PMsg` | `crates/node/src/gs_tbk_scheme/verify_phase.rs`、`crates/intergration_test/src/node/node1/node1.rs` |
| Proxy | 收齐 Node 的 Open phase one / phase two 消息后广播聚合结果 | `crates/proxy/src/gs_tbk_scheme/open_phase.rs`、`crates/intergration_test/src/proxy/proxy_node.rs` |
| Node | Open phase three 将聚合结果与本地注册表对照，输出 `maybe malicious`、`user_id`、`user_name` 和地址 | `crates/node/src/gs_tbk_scheme/open_phase.rs` |

## 链上记录对应关系

| 用户 | 角色含义 | `Signature` TX | `Signature` 区块 | `PersonalInfo` TX | `PersonalInfo` 区块 | 身份密文 SHA-256 |
| --- | --- | --- | --- | --- | --- | --- |
| `e2e20260512T153825Z_user1` | 恶意签名 demo 目标 | `0x6241dbee06f3de44c1f8090549e7e835ba8c7d7bf7c529251370e98da2396edb` | `51` | `0xfc5613668bf381f3bd0d9b939688a909148ceddf612906c9f1a23d9ac6c6c907` | `53` | `ee45a06a599c74455f614ecfaee121afdf669b921507747e48b547ccf83c2b29` |
| `e2e20260512T153825Z_user2` | 正常签名对照用户 | `0xfceab5a2c4927e908499d4a517f6c5d1fe9c3f62d2bb3c6c9e3e81d19169ff23` | `52` | `0x9b52c5c553b00196223b36ea70fb9b9c5d583ec1053d24e60ea2b87da4dcacd9` | `54` | `5d5085dbf9bf92c65660b7419c86e19ecab490acacec19ba762301300c01fa3d` |

判读方式：

- `Signature` 记录证明该用户的匿名签名已经写链，Node 的 Verify 输入可追溯到链上记录。
- `PersonalInfo` 记录证明同一用户的身份密文和证明材料已经写链，后续监管审计能按用户、TX 和区块高度复核。
- `select exists true` 证明当前合约表可查到该用户记录；历史区块查询可复用 `docs/evidence/audit-query-demo.md` 中的 `run-audit-query-demo.sh`。

## Verify/Open 关键日志

正式报告记录 4 个 Node 日志均出现 `Signature query stdout: exists true`、`Open Phase is starting` 和 `Open phase is finished!`：

| Node | 日志路径 | 日志 SHA-256 | Verify 查询 | Open |
| --- | --- | --- | --- | --- |
| `node1` | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node1.out` | `50a6cbf2772f5323ef766467da0206ccb388268f3a848b695382ce8e83595a16` | `exists true` | 完成 |
| `node2` | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node2.out` | `50a6cbf2772f5323ef766467da0206ccb388268f3a848b695382ce8e83595a16` | `exists true` | 完成 |
| `node3` | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node3.out` | `5d0df5eca6e5d27e6c3967bfab14dfcb3635aef7e9cb2125d258e4ab142065d2` | `exists true` | 完成 |
| `node4` | `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/node4.out` | `50a6cbf2772f5323ef766467da0206ccb388268f3a848b695382ce8e83595a16` | `exists true` | 完成 |

Open 详细输出可在 VM 上按日志路径提取，核心判读关键字来自 `crates/node/src/gs_tbk_scheme/open_phase.rs`：

```text
This user <id> maybe used a revoked key!
This user <id> maybe used a invaild key!
This user <id> maybe malicious!
user_id:<id>
user_name:<name>
user address:<address>
Open phase is finished!
```

其中 `revoked key` 与 `invaild key` 是实现里对两类异常的日志分支；无论落入哪个分支，`maybe malicious`、`user_id`、`user_name` 和地址共同构成揭示结果。当前 demo 的预期目标是 `user1`，即链上用户名 `e2e20260512T153825Z_user1`、协议用户编号 `1`、默认监听地址 `127.0.0.1:60001`。

## 只读摘要脚本

新增脚本 `scripts/evidence/run-malicious-open-demo.sh` 用于从已有 manifest 和角色日志生成一份小摘要，不连接链、不读取真实 `conf/config.toml`，也不会写入运行秘密。

在 VM 上已有运行日志时执行：

```bash
bash scripts/evidence/run-malicious-open-demo.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --output-dir /tmp/gstbk-malicious-open-20260512T153825Z
```

只看恶意 demo 用户：

```bash
bash scripts/evidence/run-malicious-open-demo.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --user user1
```

输出文件为 `malicious-open-summary.md`，包含：

- demo 用户与签名入口：`user1 -> sign_wrong`、`user2 -> sign`。
- `Signature` / `PersonalInfo` 的 TX 哈希、区块、`ret`、`select exists` 和身份密文 SHA-256。
- 每个 Node 日志里的 `Signature query`、Verify 结果、Open 状态和揭示摘录。

## 面试讲解口径

可以按三段讲：

1. 匿名性：User 生成群签名后，链上只保存签名 JSON 和用户记录主键；外部观察者能校验签名属于群，却不能直接从签名看出真实身份。
2. 可揭示性：监管场景下，Node 从链上查回签名并做 Verify；如果签名异常，多个 Node 通过 Open 份额协作，让 Proxy 聚合中间值，再由 Node 对照本地注册表揭示 `user_id`、`user_name` 和地址。
3. 可审计性：`Signature` 与 `PersonalInfo` 的 TX 哈希、区块高度、`select exists true`、历史查询和身份密文 SHA-256，把“签名输入、验证失败、Open 输出、身份密文上链记录”连成可复核证据链。

更简短的版本：

> 这个 demo 不是把匿名性取消，而是展示“正常情况下可匿名验证，监管触发时可由多节点协同揭示”。`user1` 故意生成异常签名，Node 从链上取签名后验证失败，于是进入 Open，最终日志给出 `user_id`、`user_name` 和地址；链上的签名与身份密文记录则用 TX 哈希和区块高度支撑审计。

## 不做的事

- 不把测试身份字段、生成密钥、运行日志大文件或真实链端配置提交进仓库。
- 不把当前工程表述为完整生产系统；它仍是生产化 smoke（冒烟验证）通过的工程原型。
- 不在本任务中重构 `intergration_test` 历史拼写、协议消息结构或密码学实现。
