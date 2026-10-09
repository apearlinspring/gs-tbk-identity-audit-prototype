# 链上审计查询 Demo

通过用户、合约、区块高度和交易哈希，可以查询 `PersonalInfo` 身份密文记录与 `Signature` 签名记录。下面给出摘要脚本和手工查询命令。

## 审计链路

```text
User
-> PersonalInfo / Signature register
-> Java SDK 返回 transactionHash 与 blockNumber
-> select 查询当前合约记录
-> history / selectWithBlockNumber 按区块高度查询历史记录
-> 对照 E2E manifest 与摘要报告
```

查询结果：

- `register` 成功时，`transactionHash` 与 `blockNumber` 标记记录写入的交易和区块。
- `select` 返回 `exists true` 和 `signature <json>` 或 `info <json>` 时，说明当前合约表仍可查到该用户记录。
- `history` 是 Java 调用脚本暴露的 `selectWithBlockNumber` 包装命令；在登记区块查询返回 `ret 0` 时，说明能按区块高度追溯到历史记录。
- 登记前一区块的 `history` 通常返回 `ret -2`，说明该用户在该合约中尚无可追溯历史快照。

## 环境准备

在已配置 Java SDK 和链节点的环境中设置：

```bash
export FISCO_CONFIG=/path/to/chain-apps/fisco-bcos-java-sdk/conf/config.toml
export FISCO_GROUP=group0
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...
```

## 摘要脚本

`scripts/evidence/run-audit-query-demo.sh` 会读取 `run-e2e.sh` 生成的 manifest，自动取出用户、合约地址、TX 哈希和登记区块，然后对每个用户执行：

- `Signature select`
- `Signature history <signatureBlock>`
- `Signature history <signatureBlock - 1>`
- `PersonalInfo select`
- `PersonalInfo history <personalInfoBlock>`
- `PersonalInfo history <personalInfoBlock - 1>`

复核命令：

```bash
bash scripts/evidence/run-audit-query-demo.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json \
  --output-dir /tmp/gstbk-audit-query-summary
```

只生成命令计划、不连接真实链：

```bash
bash scripts/evidence/run-audit-query-demo.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json \
  --dry-run
```

只复核单个用户：

```bash
bash scripts/evidence/run-audit-query-demo.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json \
  --user user1
```

脚本输出目录包含每次查询的标准输出文件、`audit-query-summary.md` 和 `audit-query-summary.json`。摘要表会把 User、Contract、TX 哈希、登记区块、查询命令、输出文件和 `exists` / `ret` 结果放在同一行。

## 手工命令

没有 manifest 时，可以手工查询。将合约地址、用户和区块号替换为实际值：

```bash
APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
USER_ID=user1
SIGNATURE_BLOCK=100
PERSONAL_INFO_BLOCK=101

bash "$APP_DIR/signature_run.sh" select "$GSTBK_SIGNATURE_CONTRACT_ADDRESS" "$USER_ID"
bash "$APP_DIR/signature_run.sh" history "$GSTBK_SIGNATURE_CONTRACT_ADDRESS" "$USER_ID" "$SIGNATURE_BLOCK"
bash "$APP_DIR/signature_run.sh" history "$GSTBK_SIGNATURE_CONTRACT_ADDRESS" "$USER_ID" "$((SIGNATURE_BLOCK - 1))"

bash "$APP_DIR/info_run.sh" select "$GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" "$USER_ID"
bash "$APP_DIR/info_run.sh" history "$GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" "$USER_ID" "$PERSONAL_INFO_BLOCK"
bash "$APP_DIR/info_run.sh" history "$GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" "$USER_ID" "$((PERSONAL_INFO_BLOCK - 1))"
```

审计复核时，先用 `select` 确认当前值，再用 `history` 在登记区块确认历史值，最后用登记前一区块说明该记录在写入前不可追溯。
