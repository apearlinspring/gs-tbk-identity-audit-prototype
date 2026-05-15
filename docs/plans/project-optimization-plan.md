# 项目优化执行计划

## 当前阶段定位

截至 2026-05-13，当前项目已经可以定位为：

> 可复现、可审计、可项目讲解的分布式身份监管工程原型。

它已经不是“资料包”或“玩具 demo（演示工程）”。项目已完成 Rust（系统级编程语言）协议流程、FISCO BCOS（金融区块链合作联盟开源区块链底层平台）链端合约、Java SDK（Software Development Kit，软件开发工具包）调用层、身份字段 CL 同态加密（Castagnos-Laguillaumie 同态加密）/ZKP（Zero-Knowledge Proof，零知识证明）、多角色 E2E（End-to-End，端到端）验证、runtime（运行时）配置隔离、CI（Continuous Integration，持续集成）强门禁、本地 service supervisor（服务管理器）、真实 VM（Virtual Machine，虚拟机）证据、失败场景库、审计查询、恶意用户 Verify/Open（验证/揭示）、JSON（JavaScript Object Notation，数据交换格式）摘要和项目讲解包。

但它还不能表述为“可上线生产系统”。生产系统还需要长期运行、监控告警、安全配置、错误恢复、部署自动化、权限隔离、多环境发布和运维治理等能力。后续优化应围绕“可复现、可运维、可审计、可交接”继续推进，而不是优先堆新功能。

当前可支撑项目表述：

> 基于 Rust + FISCO BCOS 的分布式身份监管工程原型，完成身份字段 CL 同态加密/ZKP、用户签名与身份密文上链、1 Proxy（代理）+ 4 Node（管理员节点）+ 2 User（用户）多节点 E2E、链上审计查询、异常签名 Verify/Open 和生产化 smoke 验证；对项目进行工程化改造，补齐服务化运行、自动化验证、失败场景库、JSON 摘要和项目讲解材料，使系统具备可复现、可审计、可交接能力。

## 完成度总览

| 方向 | 当前状态 | 证据或入口 |
| --- | --- | --- |
| 项目结构整理 | 已完成 | `README.md`、`AGENTS.md`、`docs/`、`crates/` |
| 链端合约 | 已完成 | `contracts/fisco-bcos/`、`docs/evidence/fisco-contracts-phase1.md` |
| Java SDK 调用闭环 | 已完成 | `chain-apps/fisco-bcos-java-sdk/`、`docs/evidence/fisco-java-sdk-stage2.md` |
| Rust 身份字段处理 | 已完成 | `crates/id_info_process`、`scripts/run-local/run-id-info.sh` |
| Rust 到链端 E2E | 已完成 | `docs/evidence/runtime-summary.md`、`docs/evidence/e2e-repro-stage3.md` |
| runtime 配置隔离 | 已完成 | `run-e2e.sh` 默认使用 runtime config，不再污染 legacy fixture |
| role entrypoints（角色运行入口） | 已完成 | `run-proxy.sh`、`run-node.sh`、`run-user.sh` 默认调用正式 bin |
| 本地服务管理 | 已完成 | `scripts/run-local/gstbk-service.sh`、`docs/operations/service-supervision.md` |
| CI 强门禁 | 已完成增强版 | `cargo fmt`、`cargo build`、Java Gradle、Bash 语法、ShellCheck、Solidity 源码形态、合约/wrapper（一种包装类）一致性 |
| FISCO 运维自动化 | 已完成增强版 | `doctor.sh`、`prepare-sdk-conf.sh`、`deploy-contracts.sh`、`bootstrap-vm-smoke.sh` |
| 运行证据沉淀 | 已完成增强版 | manifest、runtime summary、正式 VM E2E 报告、交易哈希、区块高度、角色日志摘要 |
| 安全配置治理 | 已完成增强版 | `docs/operations/secrets-and-config.md`、`doctor.sh --strict-secrets`、VM strict secrets evidence |
| 发布与复现包 | 已完成增强版 | `docs/releases/v0.1-engineering-prototype.md`、`docs/releases/v0.2-auditable-prototype.md` |
| 失败场景库 | 已完成基础版 | `docs/evidence/failure-scenarios.md` |
| 审计查询 | 已完成基础版 | `docs/evidence/audit-query-demo.md`、`docs/evidence/audit-query-live-vm-20260512T153825Z.md`、`docs/evidence/audit-query-live-vm-20260512T153825Z.json` |
| 恶意用户揭示 | 已完成基础版 | `docs/evidence/malicious-open-demo.md`、`docs/evidence/malicious-open-live-vm-20260512T200205Z.md` |
| JSON 证据摘要 | 已完成基础版 | `docs/evidence/audit-query-live-vm-20260512T153825Z.json`、`docs/evidence/malicious-open-live-vm-20260512T153825Z.json` |
| 项目讲解包 | 已完成基础版 | `docs/project-briefing/project-walkthrough.md` |
| 功能层增强 | 下一阶段 | Web（网页）/API（Application Programming Interface，应用程序接口）展示、Open 揭示日志增强、AI（Artificial Intelligence，人工智能）安全衔接、生产级运维 |

## 已完成阶段

### 阶段 1：链端可编译（已完成）

目标：确认 `PersonalInfo.sol` 和 `Signature.sol` 能在实际 FISCO BCOS 环境中编译、部署和调用。

已完成内容：

- `contracts/fisco-bcos/PersonalInfo.sol`：身份隐私数据表，表名 `u_info`。
- `contracts/fisco-bcos/Signature.sol`：用户签名表，表名 `u_signatures`。
- `contracts/fisco-bcos/Table.sol`：当前合约所需的最小 KVTable（键值表）接口。
- 在 FISCO BCOS v3.6.0 VM（Virtual Machine，虚拟机）环境完成编译、部署、`register`、`select` 和 `selectWithBlockNumber` 验证。

验收证据：

- `docs/evidence/fisco-contracts-phase1.md`
- `docs/evidence/runtime-summary.md`

### 阶段 2：Java SDK 调用闭环（已完成）

目标：链端 Java 应用能被 Rust 侧脚本调用，完成写链和查链。

已完成内容：

- `chain-apps/fisco-bcos-java-sdk/` 已补齐 Gradle（构建工具）工程、合约 wrapper（包装类）、客户端和包装脚本。
- `info_run.sh` 与 `signature_run.sh` 可由 Rust 侧通过环境变量调用。
- Java SDK 能连接节点、读取区块高度、部署或复用合约、写入和查询身份密文/签名 JSON（JavaScript Object Notation，数据交换格式）。

验收证据：

- `docs/evidence/fisco-java-sdk-stage2.md`
- `docs/operations/fisco-runbook.md`

### 阶段 3：Rust 全流程 E2E（已完成）

目标：让项目在 Ubuntu（Linux 发行版）环境中能按文档复现一次端到端流程。

已完成内容：

- 在 VM 上完成 1 Proxy（代理）+ 4 Node（管理员节点）+ 2 User（用户）流程。
- 完成 KeyGen（联合密钥生成）、Join（用户加入/发证）、Revoke（撤销）、Sign（签名）、链上 register、Node select、Verify/Open（验证/揭示）。
- 身份字段 CLI（Command Line Interface，命令行接口）支持 `keygen`、`enc --input --output` 和 `verify --input`。
- 链上写入包含 `Signature` 和 `PersonalInfo`，运行证据记录交易哈希、区块高度和查询结果。

验收证据：

- `docs/evidence/e2e-repro-stage3.md`
- `docs/evidence/e2e-merge-readiness.md`
- `docs/evidence/mainline-regression-role-entrypoints.md`
- `docs/evidence/runtime-summary.md`

### 阶段 4：工程化包装（已完成）

目标：让项目更像可维护工程，而不是实验目录集合。

已完成内容：

- `.env.example`、`.gitignore`、`README.md`、`AGENTS.md`、`docs/`、`scripts/` 已补齐。
- CI 已从 advisory（建议性）检查升级为基础强门禁：
  - `cargo fmt --all -- --check`
  - `cargo build --workspace --locked`
  - `gradle --no-daemon build`
  - `bash -n scripts/run-local/*.sh scripts/fisco/*.sh`
  - `scripts/ci/check-solidity-contracts.sh`
- runtime 配置隔离已完成：默认不再写回 `crates/intergration_test` legacy fixture（历史夹具）配置。
- 角色启动脚本默认调用正式 bin，不再默认依赖 `cargo test` 长运行入口。
- FISCO 运维脚本已补齐基础版：`doctor.sh`、`prepare-sdk-conf.sh`、`deploy-contracts.sh`。

验收证据：

- `.github/workflows/ci.yml`
- `docs/ci.md`
- `docs/operations/README.md`
- `docs/operations/fisco-runbook.md`
- `scripts/run-local/README.md`

### 阶段 5：服务化运行（已完成本地 supervisor 版）

目标：从“手动跑脚本 / E2E 编排”推进到“可运维进程管理”。

已完成内容：

- 新增 `scripts/run-local/gstbk-service.sh`，支持：
  - `start`
  - `stop`
  - `status`
  - `restart`
  - `tail`
- 支持管理目标：
  - `proxy`
  - `node <1|2|3|4>`
  - `user <1|2|3|4|5|6>`
  - `all`
- 默认 topology（拓扑）为 1 Proxy + 4 Node + 2 User。
- runtime 目录隔离为：
  - `pids/`
  - `runtime-logs/`
  - `runtime-config/`
  - `runtime-state/`
- VM 验证已完成：`start all`、`status all`、`tail`、`stop all` 均通过；停止后角色端口无监听残留；区块高度从 `46` 增至 `50`，User1/User2 均完成 `Signature` 和 `PersonalInfo` 写链。

验收证据：

- `docs/operations/service-supervision.md`
- `docs/evidence/runtime-summary.md`
- 最新主线提交：
  - `455bd45 feat(scripts): add local service supervisor`
  - `e5f20c0 test(service): verify service supervisor on vm`
  - `b73aaf9 docs(service): document supervision flow`

### 阶段 6：安全治理、CI 增强与发布复现（已完成基础版）

目标：补齐项目交接、提交质量和敏感配置边界，让项目更像可维护工程经历。

已完成内容：

- 新增 `docs/operations/secrets-and-config.md`，说明可入库/禁止入库材料、推荐权限、链上审计边界和身份样例脱敏原则。
- 增强 `scripts/fisco/doctor.sh`，支持敏感路径 inventory（清单）、`git check-ignore` 覆盖检查、权限 warning（告警）和 `--strict-secrets` 严格模式。
- 更新 `.gitignore` 与 Java SDK 局部 `.gitignore`，显式覆盖 wallet（钱包）、keystore（密钥库）、账户、证书、生成配置和运行材料。
- 将 `examples/id-info/user1.json` 与 `user2.json` 改为更明确的脱敏测试字段。
- CI 新增 ShellCheck（Shell 脚本静态检查器）门禁，并修复当前脚本暴露的问题。
- 新增 `docs/releases/v0.1-engineering-prototype.md` 和 `docs/releases/README.md`，沉淀最短复现路径、验收 checklist（检查清单）、版本说明、已知限制和项目讲解口径。

验收证据：

- `789af0f docs(security): document secrets and config boundaries`
- `66d726e feat(fisco): add sensitive config checks to doctor`
- `d824dad ci: add shellcheck gate`
- `2ab9fa4 docs(ci): document tightened quality gates`
- `235524f docs(release): add v0.1 engineering prototype notes`
- `60a362e docs(release): link reproducibility checklist`

## 综合后续路线

本节综合当前主线实际状态、上一轮任务编排和新的优化建议。服务化运行、CI 基础强门禁、Rust build（构建）门禁、FISCO 运维脚本、runtime 配置隔离、安全配置治理、发布复现包、部署自动化入口、合约/wrapper（一种包装类）一致性检查、真实 VM E2E 自动报告、失败场景库、审计查询/历史查询、恶意用户揭示 demo、JSON 摘要和项目讲解包都已经完成。下一阶段重点转为：展示层、结构化揭示日志、AI（Artificial Intelligence，人工智能）安全衔接和生产级运维。

### 1. 服务化运行

原计划目标：

```text
手动跑脚本 / E2E 编排
```

推进为：

```text
start / stop / status / restart / tail
```

当前状态：已完成本地 service supervisor 版。

后续不再作为短期主线任务。只有在需要更接近真实部署时继续升级：

- systemd（Linux 系统服务管理器）unit 生成。
- 容器化运行。
- 多主机服务管理。
- 服务自动恢复和健康检查。

### 2. CI 再收紧

当前状态：基础强门禁、ShellCheck 门禁、Rust build（构建）链接门禁和合约/wrapper 一致性检查已完成。

已完成：

- `cargo fmt --all -- --check`
- `LD_LIBRARY_PATH=$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-} cargo build --workspace --locked`
- Java Gradle build
- Bash 语法检查
- ShellCheck 脚本静态检查
- Solidity 源码形态检查
- 合约/wrapper 一致性离线检查
- 禁止真实 `conf/config.toml` 和 `conf/sdk` 出现在 Java CI job 中

后续建议：

- 继续观察 Rust build 门禁在 GitHub Actions（GitHub 自动化工作流）中的稳定性，重点关注 native dependency（原生依赖）安装和链接阶段日志。
- 在 VM 或具备 console（控制台）工具链的本地环境中定期补跑 `GSTBK_CHECK_GENERATED_WRAPPERS=1`，确认生成 wrapper 与已提交 wrapper 一致。
- 若后续修改 Solidity（智能合约编程语言）源码，必须同步更新 wrapper、Java client（客户端）、runner（运行脚本）和 CI 检查。

### 3. 安全配置治理

当前状态：增强版已完成。后续只在需要多主机、systemd（Linux 系统服务管理器）或生产部署时继续加深。

已完成：

- `.gitignore` 覆盖常见证书、私钥、账户、运行日志、runtime state 和生成配置。
- Java CI job 检查真实 `conf/config.toml` 与 `conf/sdk` 不存在。
- 真实证书、账户、wallet（钱包）、keystore（密钥库）和私钥不入库的原则已写入多个文档。
- `doctor.sh` 已支持敏感路径检查、权限 warning 和 `--strict-secrets`。
- `docs/operations/secrets-and-config.md` 已补齐安全配置边界。
- 已在真实 VM 上完成 `FISCO_DOCTOR_STRICT_SECRETS=1 bash scripts/fisco/doctor.sh`，结果为 `0 warning(s)`，证据见 `docs/evidence/fisco-strict-secrets-vm.md`。

后续建议：

- 如后续引入多主机或 systemd，再补充服务账户、文件属主和最小权限策略。

### 4. 发布与复现包

当前状态：增强版已完成。

后续建议：

- v0.2 release（发布）文档已新增，覆盖失败场景、审计查询、恶意揭示、真实 VM 证据、JSON 摘要和项目讲解包。
- 后续 release 文档应随新的展示层、E2E 报告和生产级运维能力同步更新。
- 若打新 tag，应新增对应 `docs/releases/` 文档，而不是覆盖 v0.1。

### 5. 部署自动化

当前状态：增强版已完成，已经具备 VM（Virtual Machine，虚拟机）上一键串联入口，并通过真实 VM E2E。

已完成：

- `doctor.sh`：环境健康检查。
- `prepare-sdk-conf.sh`：SDK 配置生成。
- `deploy-contracts.sh`：合约部署/复用与 `.env.fisco.generated` 生成。
- `bootstrap-vm-smoke.sh`：串联 SDK 配置准备、doctor（健康检查）、合约复用/部署、`.env.fisco.generated` 校验、可选 E2E 或 service smoke。
- `docs/operations/fisco-runbook.md`：VM 运行手册。
- 真实 VM 上 `bootstrap-vm-smoke.sh --smoke e2e` 已通过，正式报告见 `docs/evidence/e2e-report-20260512T153825Z.md`。

后续建议：

- 将常见 VM 网络/DNS/Gradle 离线依赖处理写成脚本分支，而不是只写在文档里。
- 如果后续需要面向他人交付，可增加 `make vm-smoke` 或更短入口，但不是当前最优先事项。

### 6. 运行观测与证据

当前状态：manifest、runtime summary、自动报告和真实 VM E2E 正式报告已完成。

已完成：

- E2E manifest 记录命令、路径、合约地址、区块高度、角色日志、身份密文 SHA-256（安全哈希算法 256 位）。
- `runtime-summary.md` 已记录阶段 3.1 到 3.6 的运行证据。
- 链上交易哈希和区块高度已人工汇总。
- `generate-e2e-report.sh` 已能从 manifest 和角色日志生成 Markdown（轻量标记语言）验收报告，覆盖成功/失败结论、交易、区块、耗时、角色阶段、日志路径和 SHA-256。
- `docs/evidence/e2e-report-20260512T153825Z.md` 已记录真实 VM E2E：区块 `50` -> `54`、4 笔 TX（Transaction，交易）哈希、角色阶段、耗时 `411` 秒和日志 SHA-256。

后续建议：

- 将现有失败场景库接入更短的 smoke 命令或自测脚本，但不把失败场景继续列为短期待办。
- 若后续新增 Web/API 展示，应复用现有 JSON 摘要，而不是重新解析大日志。

### 7. 功能层增强

当前状态：基础版已完成。工程底座已经有真实 VM E2E 证据、失败场景库、审计查询、恶意揭示和项目讲解包，下一步适合把这些能力产品化展示或结构化增强，而不是继续把已完成 demo 当作待办。

已完成：

- `docs/evidence/failure-scenarios.md`：缺合约地址、缺证书、链不可达、端口占用、错误身份字段和重复注册。
- `scripts/evidence/run-audit-query-demo.sh` 与真实 VM 报告：按用户、合约、TX 哈希和区块高度复核当前查询与历史查询。
- `scripts/evidence/run-malicious-open-demo.sh` 与真实 VM 报告：记录 `user1 -> sign_wrong`、Verify 失败触发 Open、`user_id/user_name/address` 揭示字段和 `user2` 正常对照。
- JSON 摘要输出和轻量自测：面向后续 Web/API 展示和 AI 安全审计材料复用。
- `docs/project-briefing/project-walkthrough.md`：把当前证据整理为项目展示可讲口径。

后续可选方向：

- Web/API 展示层，读取 E2E manifest、审计查询 JSON 和恶意揭示 JSON。
- Open 揭示日志增强，统一 stdout（标准输出）、log4rs（Rust 日志框架）文件日志和结构化事件，减少人工判读。
- AI 安全衔接，把匿名使用、行为留痕、异常追责的链路迁移到智能体工具调用或模型服务审计场景。
- 生产级运维，推进 systemd、容器、多环境配置、监控告警、证书轮换和最小权限策略。
- 多用户批量注册与签名。
- 合约事件订阅。

这些功能适合在工程底座继续稳定后再做。短期不应为了“看起来功能多”而牺牲可复现和可维护。

## 推荐任务优先级

短期优先级建议如下。当前工程底座已经能支撑“可复现、可审计、可项目讲解的工程原型”，下一轮应把系统从“证据可查、材料可讲”推进到“展示更直观、日志更结构化、运维更接近生产”。

```text
web-api-audit-console
-> open-reveal-structured-logs
-> ai-security-audit-bridge
-> production-ops-hardening
```

对应 worktree 建议：

1. `feat/web-api-audit-console`
   - 读取现有 E2E manifest、审计查询 JSON 和恶意揭示 JSON。
   - 提供只读 Web/API 展示，展示用户、合约、TX、区块、Verify/Open 和失败场景口径。
   - 不引入真实证书、私钥、账户或链端配置。

2. `feat/open-reveal-structured-logs`
   - 将 Open 揭示字段从 stdout/log4rs 摘要进一步整理为结构化事件。
   - 统一 `user_id`、`user_name`、地址、触发原因、Node 编号和日志 SHA-256。
   - 保持现有协议逻辑不变，优先增强可观测性。

3. `feat/ai-security-audit-bridge`
   - 将匿名使用、行为留痕、异常追责抽象为 AI 安全讲解材料或小型 demo。
   - 重点连接智能体工具调用、模型服务敏感操作审计和异常行为追责。
   - 作为毕设或项目展示方向补充，不改当前密码学主线。

4. `feat/production-ops-hardening`
   - 推进 systemd/容器化、多环境配置分层、监控告警、证书轮换和最小权限策略。
   - 把本地 service supervisor 升级为更接近生产的运维方式。

中期可选：

- `feat/systemd-units`：把本地 supervisor 推进到 systemd 管理。
- `feat/batch-users-demo`：补多用户批量注册与签名。
- `feat/contract-events-demo`：补合约事件订阅和审计展示。

## 风险与边界

- `openssl-1.1.0l.tar(1).gz` 是环境依赖来源，不是业务代码；公开仓库不保留该类原始源码包。
- 当前 Java SDK 工程已提交生成 wrapper 并完成 VM 调用闭环；合约变更后仍需重新运行 `sol2java` 或等价 wrapper 生成脚本。
- FISCO BCOS 2.x 与 3.x 的 SDK、配置和合约工具链可能不同，当前验收基于 FISCO BCOS v3.6.0。
- `gstbk-service.sh` 是本地 service supervisor，不是完整 systemd/容器平台；它提高了可运维性，但不等同于生产部署平台。
- 当前 CI 是离线基础门禁，不持有真实链配置，也不替代 VM E2E。
- 当前产物适合表述为“工程原型 / 生产化 smoke 验证通过”，不应表述为“已上线生产系统”。

## 官方参考

- [FISCO BCOS v2 Java SDK 文档](https://fisco-bcos-documentation.readthedocs.io/en/latest/docs/sdk/java_sdk/)
- [FISCO BCOS 3.0 Java SDK 文档](https://fisco-bcos-30-en-document.readthedocs.io/en/latest/docs/sdk/java_sdk/index.html)
- [FISCO BCOS KV 存储预编译合约文档](https://fisco-bcos-30-en-document.readthedocs.io/en/latest/docs/contract_develop/c%2B%2B_contract/use_kv_precompiled.html)
