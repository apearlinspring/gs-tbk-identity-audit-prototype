# 链上审计查询 demo（演示）

本文对应 `feat/audit-query-demo`，目标是把链上审计查询能力整理成可复现路径：监管方可以按 User（用户）、Contract（合约）、区块高度和 TX（Transaction，交易）哈希，追溯 `PersonalInfo` 身份密文记录与 `Signature` 签名记录。本文只记录命令和只读查询流程，不提交真实链配置、证书、账户、wallet（钱包）、keystore（密钥库）或 `conf/config.toml`。

## 审计链路

```text
User（用户）
-> PersonalInfo / Signature register
-> Java SDK（Software Development Kit，软件开发工具包）返回 transactionHash 与 blockNumber
-> select 查询当前合约记录
-> history / selectWithBlockNumber 按区块高度查询历史记录
-> 对照 E2E（End-to-End，端到端）manifest（运行清单）与证据报告
```

关键判读口径：

- `register` 输出 `transactionHash` 与 `blockNumber`，说明某个用户记录在哪一笔交易、哪一个区块写入。
- `select` 是当前查询，返回 `exists true` 和 `signature <json>` 或 `info <json>` 时，说明当前合约表仍可查到该用户记录。
- `history` 是 Java runner（运行器）暴露的 `selectWithBlockNumber` 包装命令；在登记区块查询返回 `ret 0` 时，说明能按区块高度追溯到历史记录。
- 登记前一区块的 `history` 通常返回 `ret -2`，说明该用户在该合约中尚无可追溯历史快照；如果用户曾经更新过 `PersonalInfo`，则可能返回更早的历史值。
- `Signature` 当前合约语义是首次登记后重复登记返回 `-1`；`PersonalInfo` 支持同一用户更新，并按 `user@blockNumber` 记录历史。

## 环境边界

链上查询需要本地或 VM（Virtual Machine，虚拟机）已经准备好被 `.gitignore` 忽略的真实运行材料：

```bash
export FISCO_CONFIG=/path/to/chain-apps/fisco-bcos-java-sdk/conf/config.toml
export FISCO_GROUP=group0
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
```

如果 manifest 中没有合约地址，或需要覆盖 manifest 中的地址，再显式设置：

```bash
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0xPERSONAL_INFO_CONTRACT
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0xSIGNATURE_CONTRACT
```

这些变量只在本地 shell（命令行外壳）或 VM 环境中设置，不写入仓库。

## 轻量脚本

新增脚本 `scripts/evidence/run-audit-query-demo.sh` 会读取 `run-e2e.sh` 生成的 manifest，自动取出用户、合约地址、TX 哈希和登记区块，然后对每个用户执行：

- `Signature select`
- `Signature history <signatureBlock>`
- `Signature history <signatureBlock - 1>`
- `PersonalInfo select`
- `PersonalInfo history <personalInfoBlock>`
- `PersonalInfo history <personalInfoBlock - 1>`

复核命令：

```bash
bash scripts/evidence/run-audit-query-demo.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --output-dir /tmp/gstbk-audit-query-20260512T153825Z
```

只生成命令计划、不连接真实链：

```bash
bash scripts/evidence/run-audit-query-demo.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --dry-run
```

只复核单个用户：

```bash
bash scripts/evidence/run-audit-query-demo.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --user e2e20260512T153825Z_user1
```

脚本输出目录包含每次查询的 stdout（标准输出）文件和 `audit-query-summary.md`。摘要表会把 User、Contract、TX 哈希、登记区块、查询命令、输出文件和 `exists` / `ret` 结果放在同一行，方便复核“用户 -> 合约记录 -> 区块高度/TX -> 历史查询”的链路。

## 手工命令

在没有 manifest 的情况下，也可以手工按同一口径查询。以下示例使用占位变量，不包含真实秘密材料：

```bash
APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
USER_ID=e2e20260512T153825Z_user1
SIGNATURE_BLOCK=51
PERSONAL_INFO_BLOCK=53

bash "$APP_DIR/signature_run.sh" select "$GSTBK_SIGNATURE_CONTRACT_ADDRESS" "$USER_ID"
bash "$APP_DIR/signature_run.sh" history "$GSTBK_SIGNATURE_CONTRACT_ADDRESS" "$USER_ID" "$SIGNATURE_BLOCK"
bash "$APP_DIR/signature_run.sh" history "$GSTBK_SIGNATURE_CONTRACT_ADDRESS" "$USER_ID" "$((SIGNATURE_BLOCK - 1))"

bash "$APP_DIR/info_run.sh" select "$GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" "$USER_ID"
bash "$APP_DIR/info_run.sh" history "$GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" "$USER_ID" "$PERSONAL_INFO_BLOCK"
bash "$APP_DIR/info_run.sh" history "$GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" "$USER_ID" "$((PERSONAL_INFO_BLOCK - 1))"
```

`history` 与 `selectWithBlockNumber` 等价，也可直接调用：

```bash
bash "$APP_DIR/signature_run.sh" selectWithBlockNumber "$GSTBK_SIGNATURE_CONTRACT_ADDRESS" "$USER_ID" "$SIGNATURE_BLOCK"
bash "$APP_DIR/info_run.sh" selectWithBlockNumber "$GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" "$USER_ID" "$PERSONAL_INFO_BLOCK"
```

## 已有 VM 证据映射

2026-05-12 真实 VM E2E 报告 `docs/evidence/e2e-report-20260512T153825Z.md` 已记录以下链上写入证据，可作为审计查询脚本的输入来源：

| 用户 | 合约 | TX（Transaction，交易）哈希 | 登记区块 | 当前查询 |
| --- | --- | --- | --- | --- |
| `e2e20260512T153825Z_user1` | `Signature` | `0x6241dbee06f3de44c1f8090549e7e835ba8c7d7bf7c529251370e98da2396edb` | `51` | `exists true` |
| `e2e20260512T153825Z_user1` | `PersonalInfo` | `0xfc5613668bf381f3bd0d9b939688a909148ceddf612906c9f1a23d9ac6c6c907` | `53` | `exists true` |
| `e2e20260512T153825Z_user2` | `Signature` | `0xfceab5a2c4927e908499d4a517f6c5d1fe9c3f62d2bb3c6c9e3e81d19169ff23` | `52` | `exists true` |
| `e2e20260512T153825Z_user2` | `PersonalInfo` | `0x9b52c5c553b00196223b36ea70fb9b9c5d583ec1053d24e60ea2b87da4dcacd9` | `54` | `exists true` |

审计复核时，先用 `select` 确认当前值，再用 `history` 在登记区块确认历史值，最后用登记前一区块说明该记录在写入前不可追溯。这样就能把用户身份密文、用户签名、链上合约记录、TX 哈希和区块高度连成一条可解释的审计链。
