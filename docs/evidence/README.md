# 测试与证据材料

本目录收录运行记录、失败场景和演示步骤。历史结果与当前复现命令分别写在对应文档中。

## 证据索引

- `runtime-summary.md`：2026 年 5 月的运行结果与复现入口。
- `failure-scenarios.md`：失败场景库，覆盖缺合约地址、缺证书、链不可达、端口占用、错误身份字段和重复注册。
- `audit-query-demo.md`：链上审计查询演示，使用 `PersonalInfo` / `Signature` 的 `select`、`selectWithBlockNumber`、交易哈希和区块高度生成查询摘要。
- `malicious-open-demo.md`：异常签名触发 Verify 失败和 Open 的演示及摘要生成方式。
- `event-schema.md`：结构化 `events[]` 事件格式，供审计台读取。
- `e2e-merge-readiness.md`：阶段 3.2 合并前的验收记录。
- `e2e-repro-stage3.md`：阶段 3 E2E 复现命令、失败场景和处理记录。
- `fisco-contracts-phase1.md`：FISCO BCOS v3.6.0 环境下 `PersonalInfo` 和 `Signature` 合约的编译、部署和调用验证记录。
- `fisco-java-sdk-stage2.md`：阶段 2 Java SDK 调用闭环联调记录。

## 摘要生成

`scripts/evidence/generate-e2e-report.sh` 从 `run-e2e.sh` 的 manifest 和日志生成 Markdown 运行报告。输出到运行目录，例如：

```bash
bash scripts/evidence/generate-e2e-report.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json \
  --output /tmp/gstbk-e2e-report.md
```

审计查询和恶意揭示摘要可基于 manifest 生成：

```bash
bash scripts/evidence/run-audit-query-demo.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json \
  --output-dir /tmp/gstbk-audit-query-summary

bash scripts/evidence/run-malicious-open-demo.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json \
  --output-dir /tmp/gstbk-malicious-open-summary
```

两个脚本生成 Markdown 和 JSON 摘要，记录 manifest 路径与 SHA-256、查询或日志路径、交易哈希、区块号、Verify/Open 状态和 `reveal_fields` 揭示字段。

## 控制台证据刷新

`scripts/evidence/refresh-audit-console-evidence.sh` 将已完成的 E2E 运行整理成审计台可读取的当前证据。

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json
```

默认输出：

| 文件 | 用途 |
| --- | --- |
| `docs/evidence/console-current-audit-query.json` | 控制台当前链上审计查询批次。 |
| `docs/evidence/console-current-malicious-open.json` | 控制台当前 Verify/Open 批次。 |
| `docs/evidence/console-current-audit-query.md` | 当前链上审计查询 Markdown 摘要，便于人工复核。 |
| `docs/evidence/console-current-malicious-open.md` | 当前 Verify/Open Markdown 摘要，便于人工复核。 |

这些 `console-current-*` 文件已被 `.gitignore` 忽略，适合在本地、虚拟机或服务器展示环境中反复覆盖。

常用参数：

- `--dry-run-audit`：链上审计查询只生成命令计划，不连接 FISCO BCOS。
- `--user <name>`：只刷新指定 manifest 用户、协议用户编号或链上用户名，可重复传入。
- `--console-root <path>`：控制台部署目录不等于仓库根目录时，指定实际部署根目录。
- `--target-dir <path>`：指定 JSON 摘要安装目录，默认是 `<console-root>/docs/evidence`。
- `--restart-service [name]`：刷新后重启 systemd 服务，默认服务名为 `gstbk-audit-console`。

## 自测

离线自测使用样例检查 JSON 结构、默认输出文件名、显式 `--json-output` 和 Verify/Open 判读语义：

```bash
bash scripts/evidence/self-test-json-output.sh
```

结构化 `events[]` 事件格式的样例位于 `examples/evidence/events.sample.json`：

```bash
bash scripts/evidence/self-test-event-schema.sh
```
