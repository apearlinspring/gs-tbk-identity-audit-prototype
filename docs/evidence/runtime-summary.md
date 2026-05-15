# 运行证据摘要

本文件记录阶段 3：Rust（系统级编程语言）全流程端到端复现、阶段 3.1：E2E（End-to-End，端到端）生产化加固、阶段 3.2：合并前生产化 smoke（冒烟验证）加固、阶段 3.3：runtime（运行时）配置隔离验证、阶段 3.4：role entrypoints（角色运行入口）验证、阶段 3.5：role entrypoints 合入主线后的生产化回归验证、阶段 3.6：service supervision（服务管理）脚本化、阶段 3.7：Rust build（构建）门禁 VM（Virtual Machine，虚拟机）验证、阶段 3.8：真实 VM bootstrap E2E 正式验收报告、阶段 3.9：真实 VM 审计查询和恶意揭示 Markdown/JSON（JavaScript Object Notation，数据交换格式）摘要，以及阶段 3.10：真实 VM 恶意揭示日志捕获复核。详细命令、输出片段和失败处理见 `docs/evidence/e2e-repro-stage3.md`，合并前验收表见 `docs/evidence/e2e-merge-readiness.md`，主线回归详单见 `docs/evidence/mainline-regression-role-entrypoints.md`，正式报告见 `docs/evidence/e2e-report-20260512T153825Z.md`，审计与揭示摘要见 `docs/evidence/audit-query-live-vm-20260512T153825Z.md`、`docs/evidence/audit-query-live-vm-20260512T153825Z.json`、`docs/evidence/malicious-open-live-vm-20260512T153825Z.md`、`docs/evidence/malicious-open-live-vm-20260512T153825Z.json` 和 `docs/evidence/malicious-open-live-vm-20260512T200205Z.md`。

## 环境

| 字段 | 记录 |
| --- | --- |
| 运行日期 | 2026-05-11；阶段 3.6 服务管理验收为 2026-05-12；阶段 3.7 Rust build 门禁验证为 2026-05-12；阶段 3.8 bootstrap E2E 正式报告为 2026-05-12；阶段 3.9 审计查询和恶意揭示摘要为 2026-05-13；阶段 3.10 恶意揭示日志捕获复核为 2026-05-13 |
| VM（Virtual Machine，虚拟机） | `gstbk-vm` / `192.168.1.24` / Ubuntu 22.04.4 LTS |
| 临时目录 | 阶段 3：`/tmp/gstbk-e2e-smoke`；阶段 3.1：`/tmp/gstbk-e2e-31`；阶段 3.2：`/tmp/gstbk-e2e-32-git-run`；阶段 3.3：源码 `/tmp/gstbk-runtime-config-verify`，运行 `/tmp/gstbk-runtime-config-e2e`；阶段 3.4：源码 `/tmp/gstbk-role-entrypoints-verify`，运行 `/tmp/gstbk-role-entrypoints-e2e`；阶段 3.5：源码 `/tmp/gstbk-mainline-regression-verify`，运行 `/tmp/gstbk-mainline-regression-e2e`；阶段 3.6：源码 `/tmp/gstbk-service-supervision-verify`，运行 `/tmp/gstbk-service-supervision-runtime`；阶段 3.7：源码 `/tmp/gstbk-rust-build-gate-vm-validation-20260512T140835Z`；阶段 3.8：源码 `/tmp/gstbk-vm-bootstrap-e2e-report-verify`，运行 `/tmp/gstbk-e2e-vm-smoke`；阶段 3.9：源码 `/tmp/gstbk-vm-live-json-evidence-verify-20260512T195610Z`，审计输出 `/tmp/gstbk-live-audit-query-20260512T153825Z`，揭示输出 `/tmp/gstbk-live-malicious-open-20260512T153825Z`；阶段 3.10：源码 `/tmp/gstbk-open-reveal-log-capture-verify`，运行 `/tmp/gstbk-open-reveal-log-capture-runtime`，揭示输出 `/tmp/gstbk-open-reveal-log-capture-summary-20260512T200205Z` |
| Rust/Cargo | `rustc 1.75.0` / `cargo 1.75.0` |
| Java/Gradle | OpenJDK 11.0.30 / Gradle 8.10.2 |
| 系统依赖 | `gcc/g++ 11.4.0`、GNU Make 4.3、GMP `libgmp-dev 6.2.1`、PARI/GP 可用、Bison 3.8.2、Clang/libclang 14 |
| FISCO BCOS（金融区块链合作联盟开源区块链底层平台） | v3.6.0，节点目录 `/home/gstbk/fisco/nodes/127.0.0.1` |
| Java SDK（Software Development Kit，软件开发工具包）配置 | 阶段 3.3 使用 `/tmp/gstbk-runtime-config-verify/chain-apps/fisco-bcos-java-sdk/conf/config.toml`，阶段 3.5 使用 `/tmp/gstbk-mainline-regression-verify/chain-apps/fisco-bcos-java-sdk/conf/config.toml`，阶段 3.6 使用 `/tmp/gstbk-service-supervision-verify/chain-apps/fisco-bcos-java-sdk/conf/config.toml`，阶段 3.8 使用 `/tmp/gstbk-vm-bootstrap-e2e-report-verify/chain-apps/fisco-bcos-java-sdk/conf/config.toml`，阶段 3.9 使用 `/tmp/gstbk-vm-live-json-evidence-verify-20260512T195610Z/chain-apps/fisco-bcos-java-sdk/conf/config.toml`，证书复制自 `/home/gstbk/fisco/nodes/127.0.0.1/sdk` |

## 链端状态

| 字段 | 记录 |
| --- | --- |
| 运行节点 | 4 个 `fisco-bcos` 进程：`node0` 到 `node3` |
| 端口 | `20200`、`20201`、`30300`、`30301` 监听中 |
| Group（组） | `group0` |
| `console.sh getBlockNumber` / Java SDK `blockNumber` | 成功；阶段 3.2 Git worktree 编排前区块 `30`，完成后区块 `34`；阶段 3.3 runtime 配置隔离复跑前区块 `34`，完成后区块 `38`；阶段 3.4 role entrypoints 复跑前区块 `38`，完成后区块 `42`；阶段 3.5 主线回归前区块 `42`，完成后区块 `46`；阶段 3.6 服务管理验收前区块 `46`，完成后区块 `50`；阶段 3.8 bootstrap E2E 前区块 `50`，完成后区块 `54`；阶段 3.10 恶意揭示日志捕获复核前区块 `54`，完成后区块 `58` |
| `PersonalInfo` 合约 | `0x6546c3571f17858ea45575e7c6457dad03e53dbb`，部署区块 `7` |
| `Signature` 合约 | `0xcceef68c9b4811b32c75df284a1396c7c5509561`，部署区块 `8` |

## 构建检查

| 命令 | 结果 | 说明 |
| --- | --- | --- |
| `rustfmt crates/id_info_process/src/main.rs crates/id_info_process/src/id_process.rs --check` | 通过 | 阶段 3 只检查当时触碰的 Rust 文件，不扩大格式化 diff |
| `cargo fmt --all -- --check` | 通过 | 阶段 3.4 VM 临时 Git worktree `/tmp/gstbk-role-entrypoints-verify` 复跑通过；阶段 3.5 VM 临时 Git worktree `/tmp/gstbk-mainline-regression-verify` 复跑通过；阶段 3.6 `/tmp/gstbk-service-supervision-verify` 复跑通过 |
| `cargo check --workspace` | 通过 | 2026-05-11 复测通过；存在历史 warning（警告）和 `llvm-config` 提示，不阻塞 E2E |
| `cargo check -p intergration_test --bins --locked` | 通过 | 阶段 3.4 VM 验证 `gstbk-proxy`、`gstbk-node`、`gstbk-user` 三个 bin（二进制入口）可编译 |
| `LD_LIBRARY_PATH=$PWD/crates/cl_encrypt:$LD_LIBRARY_PATH cargo check --workspace --locked` | 通过 | 阶段 3.4、阶段 3.5 和阶段 3.6 VM 复跑通过；存在历史 warning 和 `llvm-config` 提示，不阻塞 |
| `LD_LIBRARY_PATH=$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-} cargo build --workspace --locked` | 通过 | 阶段 3.7 VM 复跑通过，耗时约 `4m 01s`；链接阶段通过，仅保留历史 warning 和 future-incompatibility（未来不兼容）提示 |
| `cargo test -p id_info_process -- --test-threads=1` | 通过 | 12 个测试通过 |
| `bash -n scripts/run-local/run-id-info.sh scripts/run-local/render-configs.sh scripts/run-local/run-e2e.sh scripts/run-local/run-node.sh scripts/run-local/run-user.sh` | 通过 | 在 VM Git worktree 中检查 |
| `D:\Git\bin\bash.exe -n scripts/run-local/*.sh` | 通过 | 2026-05-11 Windows worktree 本轮 runtime 配置隔离改造后检查；系统 `bash.exe` 指向 WSL（Windows Subsystem for Linux，Windows Linux 子系统）且缺 `/bin/bash`，改用 Git for Windows（Windows 版 Git）自带 Bash（Bourne Again Shell，命令行外壳） |
| `bash -n scripts/run-local/*.sh scripts/fisco/*.sh` | 通过 | 阶段 3.4、阶段 3.5 和阶段 3.6 VM 临时 Git worktree 复跑通过 |
| `D:\Git\bin\bash.exe -n scripts/run-local/*.sh scripts/fisco/*.sh` | 通过 | 阶段 3.6 Windows worktree 使用 Git for Windows Bash 完整脚本语法检查通过；裸 `bash` 仍指向缺 `/bin/bash` 的 WSL 入口 |
| `D:\Git\bin\bash.exe -lc 'bash -n scripts/evidence/*.sh scripts/fisco/*.sh scripts/run-local/*.sh'` | 通过 | 2026-05-13 本地检查，覆盖本轮修改的 evidence（证据）脚本 |
| `bash -n scripts/evidence/run-audit-query-demo.sh scripts/evidence/run-malicious-open-demo.sh scripts/evidence/self-test-json-output.sh` | 通过 | 2026-05-13 VM 临时目录 `/tmp/gstbk-vm-live-json-evidence-verify-20260512T195610Z` 中检查 |
| `bash -n scripts/run-local/run-e2e.sh scripts/evidence/run-malicious-open-demo.sh scripts/evidence/self-test-json-output.sh` | 通过 | 2026-05-13 VM 临时目录 `/tmp/gstbk-open-reveal-log-capture-verify` 中检查 |
| `bash scripts/evidence/self-test-json-output.sh` | 通过 | 2026-05-13 本地 Git Bash 与 VM 夹具自测均通过，覆盖 JSON 结构、默认输出名、显式 `--json-output`、log4rs（Rust 日志框架）文件日志来源、结构化 `reveal_fields` 和 `user2` 全局 Open 判读语义 |
| `shellcheck scripts/run-local/run-id-info.sh scripts/run-local/render-configs.sh scripts/run-local/run-e2e.sh scripts/run-local/run-node.sh scripts/run-local/run-user.sh` | 未执行 | VM 未安装 shellcheck；`sudo -n apt-get update && sudo -n apt-get install -y shellcheck` 超过 300 秒未完成，已终止残留 apt 进程 |
| `git diff --check` | 通过 | 2026-05-13 本地 PowerShell 和 VM 临时目录均执行通过；新增摘要文档先用 `git add -N` 纳入检查范围 |

## 身份字段加密

| 步骤 | 结果 |
| --- | --- |
| `bash scripts/run-local/run-id-info.sh keygen` | 通过，正式 CLI 生成 CL 监管者密钥 |
| `run-id-info.sh enc --input examples/id-info/user1.json --output ...user1-block-personal-info.json` | 通过，`verify true`，SHA-256 `3f57de86d737695d563dde12b78c953eed512cc4ab012cdc45e1df2803f10c18` |
| `run-id-info.sh enc --input examples/id-info/user2.json --output ...user2-block-personal-info.json` | 通过，`verify true`，SHA-256 `41711e44919b498c370b256e58c548c5c29e223d381312a56c8d4da733ccfe83` |
| Rust 生成身份密文上链 | `stage3-rust-user` 写入 `PersonalInfo`，TX `0xef6abadb306536fed0ab66bc2da6e609d59a237b24904f4d514a76915a25a6ba`，区块 `12` |
| 查询验证 | `select` 和 `selectWithBlockNumber(12)` 返回 `id_enc`、`zkp_proof`、`commitment`、`other_info`，字段结构保持一致 |

阶段 3.1 的多角色编排不再复用同一个 `block_personal_info.json`：`user1` 与 `user2` 分别使用独立输入样例和独立身份密文输出。

阶段 3.2 Git worktree 复跑继续使用独立身份密文：

- `e2e20260511T063905Z_user1`: SHA-256 `17491217fd54940fe6ddd540903046edaf260044adf959e0c3889388949ac473`。
- `e2e20260511T063905Z_user2`: SHA-256 `cf978ef8d5ff73ae7e088b94970fedb0fb04d805bd22811a0d47f1e8a8a1c670`。

## Java SDK 合约验证

| 合约 | 用户 | 操作 | 结果 |
| --- | --- | --- | --- |
| `PersonalInfo` | `stage3-sdk-user` | `register` | TX `0x648b9cdc5ff24ae5db871d146ab42f1a1057789e5aceb663ad207f6b39e28555`，区块 `9` |
| `PersonalInfo` | `stage3-sdk-user` | 重复 `register` | TX `0xde03cd4aa200f069afa81ef5179440c6c42774f0329471158e102b71ac0294b6`，区块 `10`；合约返回成功，表现为覆盖/重复写入可接受 |
| `PersonalInfo` | `stage3-sdk-user` | `select` / `selectWithBlockNumber(9)` | `exists true` / `ret 0`，JSON 原样查回 |
| `Signature` | `stage3-sdk-user` | `register` | TX `0x35356afb265bbdcccc309a5fb0248ff1b080984067f0867a1f3371ec5283a8c3`，区块 `11` |
| `Signature` | `stage3-sdk-user` | `select` / `selectWithBlockNumber(11)` | `exists true` / `ret 0`，JSON 原样查回 |

## 多角色端到端

阶段 3.1 使用一键编排脚本复跑并沉淀 manifest：

- 1 个 Proxy（代理）：`0.0.0.0:50000`。
- 4 个 Node（管理员节点）：`0.0.0.0:50001` 到 `0.0.0.0:50004`。
- 2 个 User（用户）：`0.0.0.0:60001`、`0.0.0.0:60002`。
- 编排命令：`bash scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-e2e-31 --reuse-chain --contract-addresses-from-env --timeout-seconds 300`。
- 运行日志：`/tmp/gstbk-e2e-31/runtime-logs/20260511T054903Z/*.out`。
- Manifest（运行清单）：`/tmp/gstbk-e2e-31/runtime-logs/20260511T054903Z/manifest.json`。
- 结束后复核：`50000`、`50001` 到 `50004`、`60001`、`60002` 无监听残留，未发现本轮 Proxy/Node/User 测试进程残留。

阶段 3.2 在真实 Git worktree `/tmp/gstbk-e2e-32-git` 中复跑，验证配置恢复后工作树仍干净：

- 编排命令：`scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-e2e-32-git-run --reuse-chain --contract-addresses-from-env --timeout-seconds 300`。
- Manifest：`/tmp/gstbk-e2e-32-git-run/runtime-logs/20260511T063905Z/manifest.json`。
- Manifest schema：`gstbk.e2e.manifest.v2`，`success true`，耗时 `398` 秒。
- 配置恢复：manifest `config.configs_restored = "true"`；运行后 `git status --short --branch` 仅输出分支行，无配置文件改动。
- 结束后复核：`50000`、`50001` 到 `50004`、`60001`、`60002` 无监听残留。

阶段 3.3 在 VM 独立 Git worktree `/tmp/gstbk-runtime-config-verify` 中复跑默认 runtime 配置模式：

- 同步方式：将本分支 `feat/runtime-config-isolation` 的 HEAD `26cb6c5` 通过 Git bundle 克隆到 VM 临时目录。
- 编排命令：`bash scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-runtime-config-e2e --reuse-chain --contract-addresses-from-env --timeout-seconds 300`，未传 `--legacy-fixture-configs`。
- Manifest：`/tmp/gstbk-runtime-config-e2e/runtime-logs/20260511T132206Z/manifest.json`。
- Manifest schema：`gstbk.e2e.manifest.v2`，script version `run-e2e.sh stage3.3`，`success true`，耗时 `393` 秒。
- Runtime 配置：manifest `config.mode = "runtime"`，`config.runtime_config_dir = "/tmp/gstbk-runtime-config-e2e/runtime-state/20260511T132206Z/runtime-config"`，`config.legacy_fixture_configs = false`，`config.configs_restored = "not-applicable"`；`config.paths` 中 Proxy、4 个 Node 和 2 个 User 配置均指向该 runtime 目录。
- 区块高度：运行前 `blockNumber 34`，完成后 `blockNumber 38`。
- 配置残留：运行后 VM 中 `git status --short --branch` 仅输出分支行，`git diff -- crates/intergration_test/src/**/config/config_file/*.json` 为空，未发现 legacy fixture 配置改动。
- 结束后复核：`50000`、`50001` 到 `50004`、`60001`、`60002` 无监听残留。

阶段 3.4 在 VM 临时 Git worktree `/tmp/gstbk-role-entrypoints-verify` 中复跑默认 role entrypoints 模式：

- 同步方式：将 `feat/role-entrypoints` 基线 HEAD `57e2c4a` 通过 Git bundle 克隆到 VM 临时目录，并应用本轮未提交 patch（补丁）。
- 编排命令：`bash scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-role-entrypoints-e2e --reuse-chain --contract-addresses-from-env --timeout-seconds 300`，未传 `--legacy-fixture-configs`。
- Manifest：`/tmp/gstbk-role-entrypoints-e2e/runtime-logs/20260511T143029Z/manifest.json`。
- Manifest schema：`gstbk.e2e.manifest.v2`，script version `run-e2e.sh role-entrypoints`，`success true`，耗时 `393` 秒。
- Runtime 配置：manifest `config.mode = "runtime"`，`config.runtime_config_dir = "/tmp/gstbk-role-entrypoints-e2e/runtime-state/20260511T143029Z/runtime-config"`，`config.legacy_fixture_configs = false`，`config.configs_restored = "not-applicable"`；`config.paths` 中 Proxy、4 个 Node 和 2 个 User 配置均指向该 runtime 目录。
- 角色命令：manifest `roles.logs.proxy.command = "bash scripts/run-local/run-proxy.sh"`，`roles.logs.node1.command = "bash scripts/run-local/run-node.sh 1"`，`roles.logs.user1.command` 通过 `GSTBK_PERSONAL_INFO_PAYLOAD_PATH` 注入身份密文后调用 `run-user.sh 1`；默认脚本内部调用正式 bin，不再调用 `cargo test` 长运行入口。
- 区块高度：运行前 `blockNumber 38`，完成后 `blockNumber 42`。
- 配置残留：运行后 VM 中 `git status --short --branch` 只包含本轮源码/脚本文档 patch，`git diff -- crates/intergration_test/src/**/config/config_file/*.json` 为空，未发现 legacy fixture 配置改动。
- 结束后复核：`50000`、`50001` 到 `50004`、`60001`、`60002` 无监听残留。

阶段 3.5 在最新 `master` 创建的 `test/mainline-production-regression` 分支上复跑 role entrypoints 主线回归：

- 同步方式：本地分支 `test/mainline-production-regression` 与本地 `master` 均指向 HEAD（当前提交指针）`a20b0d2e6f7104e88279dd99f3a39e20a664a1d6`，通过 Git bundle（Git 打包仓库对象）克隆到 VM 临时目录 `/tmp/gstbk-mainline-regression-verify`。
- 基础门禁：`cargo fmt --all -- --check`、`LD_LIBRARY_PATH=$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-} cargo check --workspace --locked`、`bash -n scripts/run-local/*.sh scripts/fisco/*.sh` 均通过。
- 编排命令：`bash scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-mainline-regression-e2e --reuse-chain --contract-addresses-from-env --timeout-seconds 300`。
- Manifest：`/tmp/gstbk-mainline-regression-e2e/runtime-logs/20260511T152649Z/manifest.json`。
- Manifest schema：`gstbk.e2e.manifest.v2`，script version `run-e2e.sh role-entrypoints`，`success true`，耗时 `398` 秒。
- Runtime 配置：manifest `config.mode = "runtime"`，`config.runtime_config_dir = "/tmp/gstbk-mainline-regression-e2e/runtime-state/20260511T152649Z/runtime-config"`，`config.legacy_fixture_configs = false`，`config.configs_restored = "not-applicable"`；`config.paths` 中 Proxy、4 个 Node 和 2 个 User 配置均指向该 runtime 目录。
- 角色命令：manifest `roles.logs.proxy.command = "bash scripts/run-local/run-proxy.sh"`，`roles.logs.node1.command = "bash scripts/run-local/run-node.sh 1"`，`roles.logs.user1.command` 通过 `GSTBK_PERSONAL_INFO_PAYLOAD_PATH` 注入身份密文后调用 `run-user.sh 1`。
- 区块高度：运行前 `blockNumber 42`，完成后 `blockNumber 46`。
- 配置残留：运行后 VM 中 `git status --short --branch` 仅输出分支行，`git diff` 为空，未发现 legacy config JSON（JavaScript Object Notation，数据交换格式）改动。

阶段 3.6 在 `feat/service-supervision` 分支新增本地服务管理脚本：

- 基线：`v0.1-engineering-prototype` / `20ba8ce`。
- 同步方式：将当前分支 HEAD 通过 Git bundle 克隆到 VM 临时目录 `/tmp/gstbk-service-supervision-verify`，再叠加本轮未提交 patch（补丁）和新增文件；`git status --short --branch` 仅显示本轮脚本/文档改动。
- 新脚本：`scripts/run-local/gstbk-service.sh`。
- 管理命令：`start`、`stop`、`status`、`restart` 和 `tail`。
- 管理目标：`proxy`、`node <1|2|3|4>`、`user <1|2|3|4|5|6>` 和 `all`。
- Runtime 目录：默认 `runtime-state/service-supervision/`，实机验收使用隔离目录 `/tmp/gstbk-service-supervision-runtime`，下设 `pids/`、`runtime-logs/`、`runtime-config/` 和 `runtime-state/`。
- 默认拓扑：`all` 启动 1 个 Proxy、4 个 Node、2 个 User；如需 6 个 User，可设置 `GSTBK_SERVICE_USERS=6` 并补齐独立身份密文输入。
- 启动入口：继续调用 `run-proxy.sh`、`run-node.sh` 和 `run-user.sh`，这些脚本默认调用正式 bin（二进制入口），不回退 `cargo test`。
- 启动超时：默认 `GSTBK_SERVICE_START_TIMEOUT_SECONDS=300`，覆盖首次 `cargo run` 补编译角色 bin 的等待时间。
- 本地检查：`D:\Git\bin\bash.exe -n scripts/run-local/*.sh scripts/fisco/*.sh` 通过；裸 `bash` 仍指向缺 `/bin/bash` 的 WSL 入口。
- VM 基础检查：`cargo fmt --all -- --check`、`LD_LIBRARY_PATH=$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-} cargo check --workspace --locked`、`bash -n scripts/run-local/*.sh scripts/fisco/*.sh` 均通过。
- VM 链端环境：`GSTBK_SIGNATURE_APP_DIR` 和 `GSTBK_PERSONAL_INFO_APP_DIR` 指向 `/tmp/gstbk-service-supervision-verify/chain-apps/fisco-bcos-java-sdk`；复用 `Signature` 合约 `0xcceef68c9b4811b32c75df284a1396c7c5509561` 和 `PersonalInfo` 合约 `0x6546c3571f17858ea45575e7c6457dad03e53dbb`；`FISCO_CONFIG` 指向 VM 本地真实 `conf/config.toml`。
- VM 服务命令：`bash scripts/run-local/gstbk-service.sh stop all || true`、`start all`、`status all`、`tail proxy --lines 40`、`tail user 1 --lines 80`、`tail user 2 --lines 80`、`stop all` 均执行通过。
- 运行结果：Proxy 完成 KeyGen（联合密钥生成）；4 个 Node 均完成 KeyGen 和 Open（揭示），日志未发现 panic；User1/User2 完成 Join（加入）和 Sign（签名），且均出现 `Signature register stdout:` 与 `PersonalInfo register stdout:`。
- 链上结果：运行前 `blockNumber 46`，完成后 `blockNumber 50`；User1 写入 `Signature` TX `0x2e03ec5d2b8ace7b41076d0fe89b3bafc4676a5a1c7534590ac92e6cfbe2f4b6`（区块 `47`）和 `PersonalInfo` TX `0x8289f900dbbed7cc081378cd49a6d2457e201f2dc78a61cadff86055bfed427e`（区块 `49`）；User2 写入 `Signature` TX `0x616664f98b8792910c6dd07fdab38a2c7809c7731907f1e86e58d89087619324`（区块 `48`）和 `PersonalInfo` TX `0xf2deec6e32e635d8fc91962349ffd4b31563d57ef3144b0664c705440c11285f`（区块 `50`）。
- 停止结果：`stop all` 后 `status all` 显示 Proxy、4 个 Node、2 个 User 均为 `stopped`；端口 `50000`、`50001` 到 `50004`、`60001`、`60002` 均无监听残留。
- 配置隔离：`git diff -- crates/intergration_test/src/**/config/config_file/*.json` 为空，未污染 legacy fixture（历史夹具）配置。

阶段 3.7 在 `chore/rust-build-gate-vm-validation` 分支验证 Rust build 门禁：

- 同步方式：将当前分支 HEAD `2b7d6a8` 通过 Git bundle 克隆到 VM 临时目录 `/tmp/gstbk-rust-build-gate-vm-validation-20260512T140835Z`。
- 基础命令：`cargo fmt --all -- --check` 通过；`rustc 1.75.0` / `cargo 1.75.0`。
- 构建命令：`LD_LIBRARY_PATH=$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-} cargo build --workspace --locked`。
- 运行结果：退出码 `0`，`Finished dev [unoptimized + debuginfo] target(s) in 4m 01s`。
- 日志摘要：保留 `cl_encrypt` 未使用导入/变量、`intergration_test` 非 snake_case（蛇形命名）等历史 warning；Cargo 报告 `cexpr v0.3.6` 和 `nom v4.2.3` 未来 Rust 版本可能拒绝的提示。未出现链接失败或 native library（原生库）缺失。
- 结论：Rust CI（Continuous Integration，持续集成）门禁可从 `cargo check --workspace --locked` 升级为 `cargo build --workspace --locked`，并继续通过 `LD_LIBRARY_PATH` 指向 `crates/cl_encrypt`。

阶段 3.8 在 `test/vm-bootstrap-e2e-report-regression` 分支生成真实 VM E2E 正式验收报告：

- 同步方式：本地分支 HEAD `f7dd0b19472548ecf604056e122f1cd2160b344a` 通过 Git bundle 克隆到 VM 临时目录 `/tmp/gstbk-vm-bootstrap-e2e-report-verify`；VM 侧 `git status --short --branch` 仅输出分支状态，未出现源码改动。
- Bootstrap（启动编排）命令：`GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle bash scripts/fisco/bootstrap-vm-smoke.sh --smoke e2e`。
- 首次尝试：未设置 `GRADLE_BIN` 时，doctor 阶段的 Java SDK `blockNumber` 调用触发 Gradle wrapper 联网下载 `gradle-8.10.2-bin.zip`，因 10000ms 连接超时失败；随后使用 VM 本地 Gradle 二进制复跑通过。
- SDK 配置准备：`prepare-sdk-conf.sh` 生成真实 VM 本地 `conf/config.toml`，复制 `/home/gstbk/fisco/nodes/127.0.0.1/sdk` 证书到临时仓库；`conf/config.toml` 权限 `600`，`conf/sdk` 与 `conf/accounts` 权限 `700`。
- Doctor：两轮 doctor 均通过，敏感路径 `git check-ignore` 覆盖检查通过，4 个 `fisco-bcos` 进程运行，端口 `20200`、`20201`、`30300`、`30301` 监听中。
- 合约：`deploy-contracts.sh --mode reuse` 复用 `PersonalInfo` `0x6546c3571f17858ea45575e7c6457dad03e53dbb` 和 `Signature` `0xcceef68c9b4811b32c75df284a1396c7c5509561`，`.env.fisco.generated` 校验通过但未提交。
- E2E 命令：`bash scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-e2e-vm-smoke --reuse-chain --contract-addresses-from-env --timeout-seconds 300`。
- Manifest：`/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json`，schema `gstbk.e2e.manifest.v2`，`success true`，耗时 `411` 秒。
- 正式报告：`docs/evidence/e2e-report-20260512T153825Z.md`，由真实 manifest 和可读取日志生成；该报告不是 fixture 样例，只提交摘要、路径和 SHA-256，不提交真实大日志、证书、私钥、`config.toml`、wallet（钱包）、keystore（密钥库）或 runtime state（运行时状态）。
- 区块高度：运行前 `blockNumber 50`，完成后 `blockNumber 54`。
- 角色阶段：Proxy 与 4 个 Node 完成 KeyGen；Proxy 完成 Revoke；2 个 User 完成 Join 和 Sign；4 个 Node 查询 `Signature` 返回 `exists true` 并完成 Open；2 个 User 均完成 `Signature` 与 `PersonalInfo` register。

阶段 3.9 在 `codex/test-vm-live-json-evidence` 分支基于真实 manifest 生成审计查询和恶意揭示 Markdown（轻量标记语言）/JSON（JavaScript Object Notation，数据交换格式）摘要：

- 同步方式：本地 HEAD `df6607a57c454337c84cfd932d650ec5844e4dea` 通过 Git bundle 克隆到 VM 临时目录 `/tmp/gstbk-vm-live-json-evidence-verify-20260512T195610Z`。
- SDK 配置准备：`prepare-sdk-conf.sh --node-sdk-dir /home/gstbk/fisco/nodes/127.0.0.1/sdk --app-dir "$PWD/chain-apps/fisco-bcos-java-sdk" --group group0 --peers 127.0.0.1:20200,127.0.0.1:20201 --force`，真实 `conf/config.toml`、证书和账户只保留在 VM 临时仓库的 ignored（已忽略）路径。
- 审计查询命令：`bash scripts/evidence/run-audit-query-demo.sh --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json --output-dir /tmp/gstbk-live-audit-query-20260512T153825Z --json-output /tmp/gstbk-live-audit-query-20260512T153825Z/audit-query-summary.json`。
- 审计摘要：`docs/evidence/audit-query-live-vm-20260512T153825Z.md` 和 `docs/evidence/audit-query-live-vm-20260512T153825Z.json`。2 个 User、2 个合约的 `select` 均为 `exists true`；登记区块 `history` 均为 `ret 0` 且记录 present；登记前一区块 `history` 均为 `ret -2` 且记录 absent；JSON 文件 SHA-256 为 `3ffe453e5596845237ad6c7f09bdaa5dc2e9ec50bfbb8fbdbb07d676fb7b56ee`。
- 恶意揭示命令：`bash scripts/evidence/run-malicious-open-demo.sh --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json --output-dir /tmp/gstbk-live-malicious-open-20260512T153825Z --json-output /tmp/gstbk-live-malicious-open-20260512T153825Z/malicious-open-summary.json`。
- 恶意揭示摘要：`docs/evidence/malicious-open-live-vm-20260512T153825Z.md` 和 `docs/evidence/malicious-open-live-vm-20260512T153825Z.json`。`user1` 对应 `sign_wrong`，4 个 Node 均显示链上 `Signature` 查询 `exists true`、Verify 失败并触发 Open、Open 完成；`user2` 为正常签名对照用户。当前真实角色日志只捕获 stdout（标准输出）里的 Verify/Open 信号，未捕获 `info!` 信息级揭示行，因此摘要中保留这一捕获边界，不把运行日志大文件写入仓库；JSON 文件 SHA-256 为 `94dd1f43ab3a0d0dba6c122ac3f4a50ab149cc6625b2b117483babcfeb8c962c`。

阶段 3.10 在 `codex/feat-open-reveal-log-capture` 分支关闭真实日志未捕获完整揭示行的边界：

- 同步方式：本地 HEAD `df6607a57c454337c84cfd932d650ec5844e4dea` 通过 Git bundle 克隆到 VM 临时目录 `/tmp/gstbk-open-reveal-log-capture-verify`，随后同步本轮修改的 `scripts/run-local/run-e2e.sh`、`scripts/evidence/run-malicious-open-demo.sh` 和 `scripts/evidence/self-test-json-output.sh`。
- 修复口径：不改 GS-TBK（Group Signatures with Time-bound Keys，带时间绑定密钥的群签名方案）密码学协议；`run-e2e.sh` 在角色退出后复制 Node 的 log4rs（Rust 日志框架）文件日志到 runtime（运行时）日志目录并写入 manifest，`run-malicious-open-demo.sh` 合并 stdout（标准输出）和 log4rs 文件日志提取 `reveal_fields`。
- E2E 命令：`bash scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-open-reveal-log-capture-runtime --reuse-chain --contract-addresses-from-env --timeout-seconds 300`。
- 恶意揭示摘要：`docs/evidence/malicious-open-live-vm-20260512T200205Z.md`。`user1` 在 4 个 Node 中均捕获 `user_id:1`、`user_name:e2e20260512T200205Z_user1` 和 `user address:"127.0.0.1:60001"`；JSON（JavaScript Object Notation，数据交换格式）摘要的结构化 `reveal_fields.address` 归一化为 `127.0.0.1:60001`。`user2` 仍为 Verify（验证）通过，Open（揭示）状态为 `global_completed_not_triggered_by_user`。

阶段 3.8 bootstrap E2E 链上写入：

| 合约 | 用户 | TX 哈希 | 区块 | 查询摘要 |
| --- | --- | --- | --- | --- |
| `Signature` | `e2e20260512T153825Z_user1` | `0x6241dbee06f3de44c1f8090549e7e835ba8c7d7bf7c529251370e98da2396edb` | `51` | `exists true` |
| `Signature` | `e2e20260512T153825Z_user2` | `0xfceab5a2c4927e908499d4a517f6c5d1fe9c3f62d2bb3c6c9e3e81d19169ff23` | `52` | `exists true` |
| `PersonalInfo` | `e2e20260512T153825Z_user1` | `0xfc5613668bf381f3bd0d9b939688a909148ceddf612906c9f1a23d9ac6c6c907` | `53` | `exists true`，身份密文 SHA-256 `ee45a06a599c74455f614ecfaee121afdf669b921507747e48b547ccf83c2b29` |
| `PersonalInfo` | `e2e20260512T153825Z_user2` | `0x9b52c5c553b00196223b36ea70fb9b9c5d583ec1053d24e60ea2b87da4dcacd9` | `54` | `exists true`，身份密文 SHA-256 `5d5085dbf9bf92c65660b7419c86e19ecab490acacec19ba762301300c01fa3d` |

关键阶段：

| 阶段 | 证据摘要 |
| --- | --- |
| KeyGen（联合密钥生成） | Proxy 日志出现 `Keygen phase is staring!` / `Keygen phase is finished!`；4 个 Node 均出现 `Keygen phase is finished!` |
| Join（用户加入/发证） | `user1`、`user2` 均出现 `Join phase is starting!` / `Join phase is finished!` |
| Revoke（撤销） | Proxy 日志两次出现 `Revoke phase is starting!` / `Revoke phase is finished!` |
| Sign（签名） | `user1`、`user2` 均出现 `Sign phase is starting!` / `Sign phase is finished!` |
| 上链 | `Signature register stdout` 和 `PersonalInfo register stdout` 均返回 TX（Transaction，交易）哈希和区块高度 |
| Verify/Open（验证/揭示） | 4 个 Node 均出现 `Signature query stdout: exists true`、`Open Phase is starting`、`Open phase is finished!` |

链上写入结果：

| 合约 | 用户 | TX 哈希 | 区块 | 查询摘要 |
| --- | --- | --- | --- | --- |
| `Signature` | `e2e20260511T054903Z_user1` | `0x35f69ac7e206b2533a21c152a4855735d525b319dcd454670f09aaf75a89546a` | `23` | `exists true`，manifest 记录 SHA-256 |
| `Signature` | `e2e20260511T054903Z_user2` | `0x56b94d51fbc148f063ae1e60e5b4b1cc7aa4f68eb343060e07b0c031ecd45fa6` | `24` | `exists true`，manifest 记录 SHA-256 |
| `PersonalInfo` | `e2e20260511T054903Z_user1` | `0x001676a51ff35b4e42d8ba578e9fa37eb0365e63875ab752dfbe87dfbee482b8` | `25` | `exists true`，身份密文 SHA-256 `3f57de86d737695d563dde12b78c953eed512cc4ab012cdc45e1df2803f10c18` |
| `PersonalInfo` | `e2e20260511T054903Z_user2` | `0x0bf98e678d2d52c84ec3a75e515cfad8c1344667aa07620d31d70308acc5d1a6` | `26` | `exists true`，身份密文 SHA-256 `41711e44919b498c370b256e58c548c5c29e223d381312a56c8d4da733ccfe83` |

阶段 3.2 合并前复跑链上写入：

| 合约 | 用户 | TX 哈希 | 区块 | 查询摘要 |
| --- | --- | --- | --- | --- |
| `Signature` | `e2e20260511T063905Z_user1` | `0x929e6b566d2b95cf09d278a925c8494a6da6017606c61e007ede1554fc7369f8` | `31` | `exists true` |
| `Signature` | `e2e20260511T063905Z_user2` | `0xd8b364623a97c07422123968e79d7ce8324b08605c06e4765e321b3e0fb19a8e` | `32` | `exists true` |
| `PersonalInfo` | `e2e20260511T063905Z_user1` | `0x66aeaa0a862d3d0c0b2f44819805ab2424fe557f814da4d63b021a1b62aa5e47` | `33` | `exists true`，身份密文 SHA-256 `17491217fd54940fe6ddd540903046edaf260044adf959e0c3889388949ac473` |
| `PersonalInfo` | `e2e20260511T063905Z_user2` | `0x75c965e4f3f5ac54d12046204db3e4b328236b29cf7248ffd017793a68e99303` | `34` | `exists true`，身份密文 SHA-256 `cf978ef8d5ff73ae7e088b94970fedb0fb04d805bd22811a0d47f1e8a8a1c670` |

阶段 3.3 runtime 配置隔离复跑链上写入：

| 合约 | 用户 | TX 哈希 | 区块 | 查询摘要 |
| --- | --- | --- | --- | --- |
| `Signature` | `e2e20260511T132206Z_user1` | `0x81da185997f8db33fe14ddc678e6fc74c429b284904a6c91bde81cf434590873` | `35` | `exists true` |
| `Signature` | `e2e20260511T132206Z_user2` | `0x200dd005ab8785648d44a3508414ebcd8a45cfc25da3c3cc5340eda04285bdff` | `36` | `exists true` |
| `PersonalInfo` | `e2e20260511T132206Z_user1` | `0x76399fabab6354c0e693ca240dc295b389dc46b546e9194ec0197bf227797653` | `37` | `exists true`，身份密文 SHA-256 `b0f303459900a73d12e50a1800c4b9fb13b5ab4d988bd9e582996982a37baa60` |
| `PersonalInfo` | `e2e20260511T132206Z_user2` | `0x8be30ef25a33466a09044d8ccc5ca14a38e909ca449db027c0650a6581da92b9` | `38` | `exists true`，身份密文 SHA-256 `ef49972ae29678bc0a5279c868f216a942666dc9fa942d2e2fb1dc47bfcc1e5b` |

阶段 3.4 role entrypoints 复跑链上写入：

| 合约 | 用户 | TX 哈希 | 区块 | 查询摘要 |
| --- | --- | --- | --- | --- |
| `Signature` | `e2e20260511T143029Z_user1` | `0xed031e9ec9b2aa507e3cf94364070fcdbe86bef23804a2497db6fa3fd6764765` | `39` | `exists true` |
| `Signature` | `e2e20260511T143029Z_user2` | `0xfec0b58101510c26f007cf991c6dfac9636545834aa321bb5e457cab938a65b3` | `40` | `exists true` |
| `PersonalInfo` | `e2e20260511T143029Z_user1` | `0xc38475b874471582e85c48fbde885fe934c26447b4f5d10d5ee1bedc83a37dec` | `41` | `exists true`，身份密文 SHA-256 `2aebd1ca20aa0a3fddea59471ee048233ad30ecdd82500fa658b296558540c43` |
| `PersonalInfo` | `e2e20260511T143029Z_user2` | `0x5329ed863c07ecf6a17b2e179e20b6b5805ee232ffd958e72afe28243100fa26` | `42` | `exists true`，身份密文 SHA-256 `502a857717e089d2eb12e3fc4a612abe81d8b485f0cd2a71e9e20ba116a3a62c` |

阶段 3.5 主线回归链上写入：

| 合约 | 用户 | TX 哈希 | 区块 | 查询摘要 |
| --- | --- | --- | --- | --- |
| `Signature` | `e2e20260511T152649Z_user1` | `0x4ee24a1d1222c63c981fb135af5ff55e28b7dbcb592b6a41467a0552fc4b1d92` | `43` | `exists true` |
| `Signature` | `e2e20260511T152649Z_user2` | `0x841ea59cf5045cf3bdcb3f967e1f10f49d4b9dee6ad06ccdfd0183c5211d5aca` | `44` | `exists true` |
| `PersonalInfo` | `e2e20260511T152649Z_user1` | `0xbb0f96a1127dae62756bd614904b8355068f1baa4df2cc26ba9e8891873e5b8b` | `45` | `exists true`，身份密文 SHA-256 `e2838b1f2506e8f1582b4db6ce9761f5d263d6bae5f025f03f6e4ffd0686349d` |
| `PersonalInfo` | `e2e20260511T152649Z_user2` | `0x8b0c56b3102ca25bc000fa59f1d075487a22b90e7df37c06e7699d8e180d83d7` | `46` | `exists true`，身份密文 SHA-256 `6aa1029f7b3d4c86ae1716dd0bc328bdf8bf5c7737abcbc0d0d2ed9237a596cb` |

## 已跑通能力与非生产级能力

已跑通能力：

- Rust 身份字段正式 CLI：`keygen`、`enc --input --output`、`verify --input`。
- Java SDK/FISCO BCOS 链端写入与查询：`register`、`select`、`history/selectWithBlockNumber`。
- 1 Proxy + 4 Node + 2 User 多角色流程：KeyGen、Join、Revoke、Sign、链上 register、Node select、Verify/Open。
- `run-e2e.sh` 支持端口占用检查、超时等待、失败尾日志、trap 清理、统一日志目录和 manifest。
- `run-e2e.sh` 阶段 3.2 支持链健康前置检查、必要环境变量预检、失败 manifest、真实命令记录、配置备份/恢复和 Git/source snapshot 记录。
- `run-e2e.sh` 阶段 3.3 默认使用 runtime 配置目录，manifest 记录 runtime config path（运行时配置路径），legacy fixture 写回仅作为显式兼容/调试模式。
- `run-proxy.sh`、`run-node.sh` 和 `run-user.sh` 默认调用正式角色 bin；旧 `cargo test` 长运行入口仅作为显式兼容/调试路径保留。
- `gstbk-service.sh` 支持本地服务管理：PID 文件、角色日志、runtime config、runtime state、按顺序启动、按反向顺序停止、状态查看和日志 tail（日志尾部查看）。
- `render-configs.sh` 支持 local 默认 `127.0.0.1` 和传入 VM/内网 IP。
- `render-configs.sh` 支持输出到 runtime 配置目录，减少 E2E 对 Git 内 legacy fixture 配置文件的写回依赖。

仍非生产级能力：

- 多角色正式入口仍复用 `crates/intergration_test` 中已验证的协议流程模块，适合 smoke（冒烟验证）和工程原型运行；`gstbk-service.sh` 是本地 supervisor（服务管理器），还不是 systemd（系统服务管理器）级别的 daemon（守护进程）部署。
- legacy fixture 配置仍保留为兼容回退路径，旧的辅助脚本如 `update_proxy_ip.sh`、`update_threshold2.sh` 和 `update_username.sh` 仍直接面向 legacy 目录；推荐新 E2E 使用 runtime 配置目录。
- VM 未安装 shellcheck；脚本已通过 `bash -n`，但还缺静态 lint（代码静态检查）门禁。
- 证书、账户、真实 `conf/config.toml` 仍需人工放置在 VM 或本地安全目录，不进入仓库。

## 异常和处理

| 问题 | 判断 | 处理 |
| --- | --- | --- |
| VM DNS 不稳定导致 Gradle 下载 Maven 依赖失败 | 环境问题 | 使用 `FISCO_CONSOLE_DIR=/home/gstbk/fisco/console`，让 Gradle 使用 console 自带 `lib/*.jar`；如需外网，可从 Windows OpenSSH 启动 `ssh -N -R 127.0.0.1:1080 gstbk-vm` |
| `cargo fmt --check` 失败 | 历史格式问题 | 记录为待办；本阶段不做全仓格式化，避免污染 E2E 复现提交 |
| Node1/Node4/Proxy 配置残留 `172.28.*` | 历史配置问题 | 改为 `127.0.0.1` 本机端口矩阵 |
| 干净 worktree 缺少 `info/` 状态目录 | 脚本缺口 | `run-node.sh` / `run-user.sh` 启动前自动创建 |
| User 签名后缺少 `personal_info.json` | 编排缺口 | `run-user.sh` 支持 `GSTBK_PERSONAL_INFO_PAYLOAD_PATH`；阶段 3.1 编排器按 User 分别注入独立身份密文 JSON |
| VM 临时源码快照不是 Git 仓库 | 脚本健壮性问题 | manifest 生成器已允许 Git 字段为 `null`，不再让成功 E2E 因 `git rev-parse` 失败而退出 |
| 缺少合约地址且传入 `--contract-addresses-from-env` | 配置问题 | 阶段 3.2 预检提前失败，manifest `success false`，错误指向缺失环境变量 |
| 端口被占用 | 环境问题 | 阶段 3.2 在启动角色前失败，manifest `success false`，错误指向端口号，未留下角色进程 |
| 缺少 User 身份字段输入样例 | 夹具问题 | 阶段 3.2 在渲染配置和启动角色前失败，manifest `success false`，错误指向缺失文件 |
| Gradle wrapper 联网下载超时 | VM 网络/离线依赖问题 | 阶段 3.8 首次 bootstrap 未设置 `GRADLE_BIN`，doctor 阶段 Java SDK `blockNumber` 因下载 `gradle-8.10.2-bin.zip` 超时失败；使用 `GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle` 复跑通过 |

## 简历可支撑点

本次记录可支撑“多节点集成测试和全流程验证”：在 Ubuntu VM 上完成 Rust 身份字段 CL 加密/ZKP 证明、Java SDK/FISCO BCOS 合约写入查询、1 Proxy + 4 Node + 2 User 多角色协同、签名上链、身份密文上链、Node 查询签名并执行 Open 揭示流程。
