# CI（Continuous Integration，持续集成）基础检查

本项目的 GitHub Actions（GitHub 自动化工作流）入口是 `.github/workflows/ci.yml`。它用于合并前的离线基础门禁，不等同于 2026-05-11 已在 VM（Virtual Machine，虚拟机）完成的 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）生产化 smoke（冒烟验证）；CI 环境不会持有真实链节点、证书、账户材料或生产 `conf/config.toml`。

## 强制门禁

- Rust（系统级编程语言）格式：执行 `cargo fmt --all -- --check`，rustfmt（Rust 格式化工具）baseline（格式化基线）已合入后不再作为 advisory（建议性）检查。
- Rust 编译与链接：执行 `LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}" cargo build --workspace --locked`，使用已提交的 `Cargo.lock` 锁定依赖解析，并覆盖 `crates/cl_encrypt/libencrypt.so` 这类 Linux native library（Linux 原生库）的链接阶段。该门禁已在 2026-05-12 的 VM（Virtual Machine，虚拟机）Ubuntu（Linux 发行版）环境验证通过，因此 CI 从原 `cargo check --workspace --locked` 升级为 build（构建）强门禁。
- Java SDK（Software Development Kit，软件开发工具包）：在 `chain-apps/fisco-bcos-java-sdk` 下执行 Gradle（构建工具）命令 `gradle --no-daemon build`，确认已提交的 wrapper（包装类）、客户端和脚本调用层可在不连接链端的情况下编译。
- 敏感链配置防线：Java job（任务）会确认 `conf/config.toml` 和 `conf/sdk` 不存在，避免把真实链配置、证书或账户材料作为 CI 依赖。
- Bash（Unix shell 命令解释器）脚本语法：对 `scripts/run-local/*.sh`、`scripts/fisco/*.sh` 和 `scripts/ci/*.sh` 逐个执行 `bash -n "$script"`，覆盖本地编排脚本、FISCO 运维脚本和 CI 辅助脚本。CI 中使用循环逐个检查，避免 `bash -n file1 file2` 只解析第一个文件、后续文件变成位置参数的问题。
- ShellCheck（Shell 脚本静态检查器）：CI 通过 Ubuntu APT（Advanced Package Tool，Debian/Ubuntu 软件包管理工具）repository（软件包仓库）安装 `shellcheck`，并执行 `shellcheck scripts/run-local/*.sh scripts/fisco/*.sh scripts/ci/*.sh`。当前唯一局部 disable 是 `scripts/run-local/gstbk-service.sh` 的 SC2016，因为该处有意把 `bash -c 'cd "$1" ... exec "$@"'` 交给子 Bash 在接收 argv（argument vector，参数向量）后展开，不能在外层提前展开。
- Solidity（智能合约编程语言）源码形态：执行 `scripts/ci/check-solidity-contracts.sh`，确认 `PersonalInfo.sol`、`Signature.sol` 和 `Table.sol` 存在，并包含基础声明。
- 合约与 Java SDK wrapper 一致性：执行 `scripts/ci/check-contract-wrapper-consistency.sh`，在不连接真实链、不读取真实 `conf/config.toml` 的情况下检查合约名、表名、KVTable（键值表）schema（结构定义）、`register` / `select` / `selectWithBlockNumber` 关键函数、ABI（Application Binary Interface，应用二进制接口）片段、wrapper 类、Java client（客户端）绑定、Gradle task（构建任务）和 runner（运行脚本）入口。该检查用于在提交前暴露 Solidity 改动后 wrapper 或 runner 失配的问题。
- Audit Console（审计控制台）：对 `apps/audit-console/server.mjs` 和 `apps/audit-console/public/app.js` 执行 Node.js（JavaScript 运行时）语法检查 `node --check`，并执行 `npm run check --prefix apps/audit-console`。该应用是零依赖 Node.js 服务，CI 不执行 `npm install`，也不连接真实链端或读取证书、私钥、wallet（钱包）、keystore（密钥库）、生产 `conf/config.toml` 和运行大日志。

上述检查均为强门禁，失败会阻塞 PR（Pull Request，拉取请求）或受保护分支合并。

## CI 与 VM E2E 边界

CI 覆盖的是仓库内可复现、无真实链材料的基础质量线。它不启动 FISCO BCOS 节点，不部署合约，不调用链上 `register` / `select` / `history`，不运行多角色长流程，也不生成或上传证书、私钥、wallet（钱包）、keystore（密钥库）、运行日志大文件和协议状态文件。

VM E2E（End-to-End，端到端）复核仍负责链端闭环：FISCO BCOS 节点启停、合约部署、Java SDK 连接真实 `conf/config.toml`、身份密文上链、签名上链、Node（管理员节点）查询 Verify/Open（验证/揭示）和交易哈希/区块高度证据。需要链上审计证据时，以 `docs/evidence/runtime-summary.md` 和 `docs/evidence/e2e-merge-readiness.md` 记录的 VM 运行结果为准。

本地或 VM 复核 Java build（构建）时，如果 Maven（Java 依赖仓库）解析受网络影响，可以设置 `FISCO_CONSOLE_DIR` 指向本机 FISCO BCOS console 目录，让 Gradle 使用 console 自带 jar（Java 归档包）完成编译；这只替代依赖来源，不等同于使用真实链配置、证书或账户。

## 审计控制台检查

`apps/audit-console` 是只读 Web（网页）/API（Application Programming Interface，应用程序接口）展示层，用于聚合仓库内已提交的 evidence JSON（JavaScript Object Notation，数据交换格式）摘要。本地最小复核命令如下：

```bash
node --check apps/audit-console/server.mjs
node --check apps/audit-console/public/app.js
npm run check --prefix apps/audit-console
```

其中 `node --check` 只做 server（服务端）和 browser app（浏览器应用）脚本语法检查；`npm run check` 会执行 `node server.mjs --check`，验证聚合读取边界和 JSON 结构。期望只扫描 `examples/evidence/*.json` 与 `docs/evidence/*.json`，不会读取真实 FISCO BCOS 节点配置、证书、私钥、wallet、keystore、`conf/config.toml` 或运行大日志。

## 合约 wrapper 一致性检查分层

本地强制检查只依赖仓库内源码，可直接运行：

```bash
bash scripts/ci/check-contract-wrapper-consistency.sh
```

该命令会检查 `contracts/fisco-bcos/PersonalInfo.sol` 与 `Signature.sol`、`chain-apps/fisco-bcos-java-sdk/src/main/java/org/gstbk/chain/contracts/` 下已提交 wrapper、`PersonalInfoClient` / `SignatureClient`、`info_run.sh` / `signature_run.sh` 和 Gradle task 是否保持一致。它不会部署合约，不会访问链节点，也不会要求真实证书、wallet（钱包）、keystore（密钥库）或 `conf/config.toml`。

工具链可选检查需要 FISCO BCOS console（控制台）目录，但仍不需要真实链配置。显式打开后，脚本会调用现有 `generate-contract-wrappers.sh`，把 wrapper 生成到临时目录，再用 diff（差异比较）确认生成结果与已提交 wrapper 一致：

```bash
GSTBK_CHECK_GENERATED_WRAPPERS=1 FISCO_CONSOLE_DIR=/path/to/console \
  bash scripts/ci/check-contract-wrapper-consistency.sh
```

真实 FISCO 环境检查仍属于 VM E2E 范畴：合约编译部署、Java SDK 连接真实 `conf/config.toml`、`register` / `select` / `history` 链上调用、交易哈希和区块高度证据，都应在 VM 复核中完成，并写入 evidence（证据）文档。CI 不持有这些材料。

## 后续收紧方向

- 继续观察 Rust build（构建）门禁在 GitHub Actions（GitHub 自动化工作流）中的稳定性；如发现链接或 native dependency（原生依赖）波动，优先补齐依赖安装和最小复现日志，而不是降级门禁。
- 在 VM 或具备 console 工具链的本地环境中定期补跑 `GSTBK_CHECK_GENERATED_WRAPPERS=1`，作为 `sol2java`（Solidity 到 Java wrapper 生成工具）等价生成路径的抽样复核。
- 后续如继续新增脚本，应同时通过 `bash -n` 和 ShellCheck；确需 disable 某条规则时，只使用局部注释并在本文件记录原因。
