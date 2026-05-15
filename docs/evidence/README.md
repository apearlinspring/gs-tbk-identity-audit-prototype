# 测试与证据材料

本目录保存与测试验收相关的资料。2026-05-11 后，本仓库的关键证据口径已经从“历史日志线索”更新为“生产化 smoke（冒烟验证）通过”：1 个 Proxy（代理）+ 4 个 Node（管理员节点）+ 2 个 User（用户）完成 Rust（系统级编程语言）到 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）的 E2E（End-to-End，端到端）闭环。2026-05-12 已补充真实 VM（Virtual Machine，虚拟机）上的 `bootstrap-vm-smoke.sh --smoke e2e` 正式验收报告；2026-05-13 又基于该真实 manifest（运行清单）补齐链上审计查询和恶意揭示摘要，不再只依赖 fixture（夹具）样例报告。

## 证据索引

- `../interview/third-party-test-evidence.md`：基于外部第三方功能测试记录整理的公开口径索引；测试原件不复制进仓库，索引只保留页码级证据、测试项、简历支撑点和口径边界。
- `runtime-summary.md`：当前运行证据摘要，包含阶段 3 Rust 全流程复现、阶段 3.1 编排脚本加固、阶段 3.2 合并前生产化 smoke 结果、runtime（运行时）配置隔离、role entrypoints（角色运行入口）和主线回归结果。
- `failure-scenarios.md`：失败场景库，覆盖缺合约地址、缺证书、链不可达、端口占用、错误身份字段和重复注册，记录触发命令、预期失败点、错误分类和恢复建议。
- `audit-query-demo.md`：链上审计查询 demo（演示），说明如何围绕 `PersonalInfo` / `Signature` 的 `select`、`selectWithBlockNumber`、TX（Transaction，交易）哈希和区块高度复核“用户 -> 合约记录 -> 区块高度/TX -> 历史查询”链路。
- `malicious-open-demo.md`：恶意用户 Verify/Open（验证/揭示）demo（演示），说明 `user1 -> sign_wrong`、Node 链上查签名、Verify 失败触发 Open、揭示 `user_id`/`user_name`/地址，以及链上审计证据如何对应。
- `event-schema.md`：结构化 `events[]` 事件格式，统一抽象审计查询、恶意揭示和失败场景，供后续 Web（网页）/API（Application Programming Interface，应用程序接口）展示和 AI（Artificial Intelligence，人工智能）安全审计材料复用。
- `audit-query-live-vm-20260512T153825Z.md`：2026-05-13 在真实 VM 上基于 `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json` 运行 `run-audit-query-demo.sh` 的只读审计查询摘要，覆盖 `select`、登记区块 `history` 和登记前一区块 `history`。
- `audit-query-live-vm-20260512T153825Z.json`：同一真实 VM manifest 生成的只读审计查询 JSON（JavaScript Object Notation，数据交换格式）摘要；只保留路径、SHA-256、TX（Transaction，交易）哈希、区块号和查询判读，文件 SHA-256 为 `3ffe453e5596845237ad6c7f09bdaa5dc2e9ec50bfbb8fbdbb07d676fb7b56ee`。
- `malicious-open-live-vm-20260512T153825Z.md`：2026-05-13 在真实 VM 上基于同一 manifest 运行 `run-malicious-open-demo.sh` 的恶意揭示摘要，记录 `user1 -> sign_wrong`、4 个 Node 的链上签名查询、Verify 失败触发 Open 和日志捕获边界。
- `malicious-open-live-vm-20260512T153825Z.json`：同一真实 VM manifest 生成的恶意揭示 JSON 摘要；只保留用户映射、TX 哈希、区块号、Verify/Open 判读、日志路径和 SHA-256，文件 SHA-256 为 `94dd1f43ab3a0d0dba6c122ac3f4a50ab149cc6625b2b117483babcfeb8c962c`。
- `malicious-open-live-vm-20260512T200205Z.md`：2026-05-13 在真实 VM 上重跑最小 E2E 后生成的恶意揭示摘要，已从 Node stdout（标准输出）和 log4rs（Rust 日志框架）文件日志中捕获 `user1` 的 `user_id`、`user_name` 和 address（地址）揭示字段；`user2` 仍保持 Verify 通过且 Open 为全局完成、非本用户触发。
- `e2e-report-20260512T153825Z.md`：2026-05-12 在真实 `gstbk-vm` 上通过 `GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle bash scripts/fisco/bootstrap-vm-smoke.sh --smoke e2e` 生成的正式 E2E 验收报告；manifest 来自 `/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json`，区块 `50` -> `54`，包含 4 笔 TX（Transaction，交易）哈希、角色阶段、耗时和日志 SHA-256。
- `e2e-report-20260511T063905Z.md`：由小型 fixture（夹具）生成的 Markdown（轻量标记语言）验收报告样例，路径格式对齐阶段 3.2 的 `/tmp/gstbk-e2e-32-git-run/runtime-logs/20260511T063905Z/manifest.json`；只保留摘要、路径和 SHA-256（安全哈希算法 256 位），不提交真实大日志。
- `mainline-regression-role-entrypoints.md`：role entrypoints 合入主线后的生产化回归验证，记录 `test/mainline-production-regression` 分支、基础门禁、manifest（运行清单）、区块 `42` -> `46`、交易哈希和 Git（分布式版本控制系统）干净状态。
- `e2e-merge-readiness.md`：阶段 3.2 合并前验收表，记录 1 Proxy + 4 Node + 2 User、区块 `30` -> `34`、交易哈希、查询结果和 Verify/Open（验证/揭示）证据。
- `e2e-repro-stage3.md`：阶段 3 E2E 复现的详细命令、输出片段、失败场景和处理记录。
- `fisco-contracts-phase1.md`：FISCO BCOS（金融区块链合作联盟开源区块链底层平台）v3.6.0 环境下 `PersonalInfo` 和 `Signature` 合约的编译、部署和调用验证记录。
- `fisco-java-sdk-stage2.md`：阶段 2 Java SDK（Software Development Kit，软件开发工具包）调用闭环的 VM（Virtual Machine，虚拟机）联调记录。
- `fisco-strict-secrets-vm.md`：FISCO BCOS 真实 VM 上 `doctor.sh --strict-secrets` 的敏感配置权限证据，记录 `conf/sdk`、`conf/accounts`、wallet（钱包）和 keystore（密钥库）路径检查结果。
- `crates/intergration_test/src/**/logs`：历史运行日志，包含 Join-Issue（加入与发证）、Revoke（撤销）、Sign（签名）、Verify 和 Open 等阶段输出。
- `crates/intergration_test/src/**/info/*.json`：历史运行中生成的密钥、用户、签名和个人信息状态文件，主要用于理解实验流程，不作为生产配置。

注意：公开仓库只保留脱敏样例和摘要。真实姓名、身份证号、密钥材料、第三方测试原件和运行大日志不进入本仓库。

## 自动报告生成

`scripts/evidence/generate-e2e-report.sh` 可从 `run-e2e.sh` 输出的 manifest（运行清单）和可读取日志生成 Markdown 验收报告，默认输出到 `docs/evidence/e2e-report-<timestamp>.md`：

```bash
bash scripts/evidence/generate-e2e-report.sh \
  --manifest /tmp/gstbk-e2e-32-git-run/runtime-logs/20260511T063905Z/manifest.json
```

也可以指定输出路径：

```bash
bash scripts/evidence/generate-e2e-report.sh \
  --manifest /tmp/gstbk-e2e-32-git-run/runtime-logs/20260511T063905Z/manifest.json \
  --output docs/evidence/e2e-report-manual.md
```

报告汇总命令、运行目录、合约地址、区块高度、TX（Transaction，交易）哈希、Role（角色）阶段、耗时、日志路径、SHA-256 和失败原因；`success false` 的 manifest 会生成失败报告，并从可读取日志中抽取有限失败线索。

审计查询和恶意揭示摘要可基于真实 manifest 生成：

```bash
bash scripts/evidence/run-audit-query-demo.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --output-dir /tmp/gstbk-live-audit-query-20260512T153825Z

bash scripts/evidence/run-malicious-open-demo.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --output-dir /tmp/gstbk-live-malicious-open-20260512T153825Z
```

`feat/open-reveal-log-capture` 分支新增的真实 VM 复核使用 `/tmp/gstbk-open-reveal-log-capture-runtime/runtime-logs/20260512T200205Z/manifest.json`，输出目录为 `/tmp/gstbk-open-reveal-log-capture-summary-20260512T200205Z`，用于验证 Node log4rs 文件日志中的揭示字段能进入 Markdown 和 JSON 摘要。

两个脚本继续保留 Markdown（轻量标记语言）摘要，同时会生成 JSON（JavaScript Object Notation，数据交换格式）摘要。默认文件名分别为 `audit-query-summary.json` 和 `malicious-open-summary.json`，也可以通过 `--json-output <path>` 指定输出路径。JSON 摘要面向后续 Web（网页）/API（Application Programming Interface，应用程序接口）展示和 AI（Artificial Intelligence，人工智能）安全审计材料复用，固定包含 `generated_at`、`manifest`、`output_dir`、`success`、`users`、`contract_addresses`、`tx_hashes`、`block_numbers`、`query_results`、`verify_open_status`、`log_sha256` 和 `notes` 等字段。

JSON 摘要只记录 manifest 路径与 SHA-256、查询/日志路径、TX（Transaction，交易）哈希、区块号、Verify/Open（验证/揭示）判读状态、`reveal_fields` 揭示字段和必要说明，不内嵌真实证书、私钥、账户、wallet（钱包）、keystore（密钥库）、`conf/config.toml`、runtime-state（运行时状态）或大日志。恶意揭示摘要中，`user1` 固定表达为 `sign_wrong` 恶意演示目标，`user2` 固定表达为正常 `sign` 对照用户；如果 `user2` Verify 通过但同一轮日志存在 Open 阶段，JSON 的 `open_status` 会写成 `global_completed_not_triggered_by_user` 或 `global_started_not_triggered_by_user`，表示全局完成/开始但非本用户触发。

## 控制台证据刷新

`scripts/evidence/refresh-audit-console-evidence.sh` 用于把一次 VM（Virtual Machine，虚拟机）E2E（End-to-End，端到端）运行转成审计控制台可读取的当前证据。它不启动 Proxy（代理）、Node（管理员节点）或 User（用户），也不会在公网页面上暴露执行入口；推荐流程是先跑完 `run-e2e.sh`，再把 manifest（运行清单）交给刷新脚本：

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --restart-service
```

默认输出：

| 文件 | 用途 |
| --- | --- |
| `docs/evidence/console-current-audit-query.json` | 控制台当前链上审计查询批次。 |
| `docs/evidence/console-current-malicious-open.json` | 控制台当前 Verify/Open（验证/揭示）批次。 |
| `docs/evidence/console-current-audit-query.md` | 当前链上审计查询 Markdown 摘要，便于人工复核。 |
| `docs/evidence/console-current-malicious-open.md` | 当前 Verify/Open Markdown 摘要，便于人工复核。 |

这些 `console-current-*` 文件已被 `.gitignore` 忽略，适合在 VM 或公网展示服务器上反复覆盖。若要把一次运行作为长期证据保存，请复制为带时间戳的 `*-live-vm-*.json` / `.md` 后再纳入 Git（分布式版本控制系统）。

常用参数：

- `--dry-run-audit`：链上审计查询只生成命令计划，不连接 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）。
- `--user <name>`：只刷新指定 manifest 用户、协议用户编号或链上用户名，可重复传入。
- `--console-root <path>`：当控制台部署目录不等于当前仓库根目录时，指定实际部署根目录。
- `--target-dir <path>`：指定 JSON 摘要安装目录，默认是 `<console-root>/docs/evidence`。
- `--restart-service [name]`：刷新后重启 systemd（Linux 系统服务管理器）服务，默认服务名为 `gstbk-audit-console`。

轻量 fixture（夹具）自测不连接真实链，可验证 JSON 结构、默认输出文件名、显式 `--json-output` 和上述 `user2` Open 判读语义：

```bash
bash scripts/evidence/self-test-json-output.sh
```

结构化 `events[]` 事件格式的样例位于 `examples/evidence/events.sample.json`。对应自测只解析样例并校验 `audit_query`、`malicious_open` 和 `failure_scenario` 三类关键字段：

```bash
bash scripts/evidence/self-test-event-schema.sh
```

2026-05-12 正式 VM E2E 报告的关键链上证据：

| 合约 | 用户 | TX（Transaction，交易）哈希 | 区块 | 查询 |
| --- | --- | --- | --- | --- |
| `Signature` | `e2e20260512T153825Z_user1` | `0x6241dbee06f3de44c1f8090549e7e835ba8c7d7bf7c529251370e98da2396edb` | `51` | `exists true` |
| `Signature` | `e2e20260512T153825Z_user2` | `0xfceab5a2c4927e908499d4a517f6c5d1fe9c3f62d2bb3c6c9e3e81d19169ff23` | `52` | `exists true` |
| `PersonalInfo` | `e2e20260512T153825Z_user1` | `0xfc5613668bf381f3bd0d9b939688a909148ceddf612906c9f1a23d9ac6c6c907` | `53` | `exists true` |
| `PersonalInfo` | `e2e20260512T153825Z_user2` | `0x9b52c5c553b00196223b36ea70fb9b9c5d583ec1053d24e60ea2b87da4dcacd9` | `54` | `exists true` |

阶段 3.2 关键链上证据：

| 合约 | 用户 | TX（Transaction，交易）哈希 | 区块 | 查询 |
| --- | --- | --- | --- | --- |
| `Signature` | `e2e20260511T063905Z_user1` | `0x929e6b566d2b95cf09d278a925c8494a6da6017606c61e007ede1554fc7369f8` | `31` | `exists true` |
| `Signature` | `e2e20260511T063905Z_user2` | `0xd8b364623a97c07422123968e79d7ce8324b08605c06e4765e321b3e0fb19a8e` | `32` | `exists true` |
| `PersonalInfo` | `e2e20260511T063905Z_user1` | `0x66aeaa0a862d3d0c0b2f44819805ab2424fe557f814da4d63b021a1b62aa5e47` | `33` | `exists true` |
| `PersonalInfo` | `e2e20260511T063905Z_user2` | `0x75c965e4f3f5ac54d12046204db3e4b328236b29cf7248ffd017793a68e99303` | `34` | `exists true` |
