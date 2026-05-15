# 运行入口

本目录保存项目运行资料。当前新人优先阅读本文件、根目录 `README.md`、`scripts/run-local/README.md`、[VM 访问与 FISCO BCOS 环境](vm-access.md)、[本地服务管理](service-supervision.md)、[FISCO BCOS 运维自动化 Runbook](fisco-runbook.md) 和 [敏感材料与配置边界](secrets-and-config.md)。

## 运行环境

推荐使用 Ubuntu（Linux 发行版）或 VM（Virtual Machine，虚拟机）。Windows（微软操作系统）环境可以编辑文档和脚本，但 `crates/cl_encrypt/libencrypt.so`、GMP（GNU Multiple Precision Arithmetic Library，多精度算术库）和 PARI/GP（数论计算系统）等依赖需要 Linux 验证。

基础依赖示例：

```bash
sudo apt-get update
sudo apt-get install -y build-essential pkg-config libgmp-dev pari-gp libpari-dev bison clang libclang-dev
```

环境变量从根目录模板开始：

```bash
cp .env.example .env
set -a
. ./.env
set +a
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"
```

`.env.example` 统一记录 Proxy（代理）、Node（管理员节点）、User（用户）、FISCO BCOS（金融区块链合作联盟开源区块链底层平台）、Java SDK（Software Development Kit，软件开发工具包）和合约地址相关变量。真实证书、私钥、账户文件和 `conf/config.toml` 不提交，详细边界见 [敏感材料与配置边界](secrets-and-config.md)。

## VM 环境摘要

阶段 1 和阶段 2 已在 FISCO BCOS v3.6.0 环境完成链端验证：

- 连接、SSH（Secure Shell，安全外壳协议）别名和工作目录约定见 [VM 访问与 FISCO BCOS 环境](vm-access.md)。
- Host（主机）：`gstbk-vm` / `192.168.1.24`，Java SDK 阶段实际 hostname（主机名）为 `gs-tbk-dev`。
- System（操作系统）：Ubuntu 22.04.4 LTS。
- Console（控制台）：`/home/gstbk/fisco/console`。
- Node 目录：`/home/gstbk/fisco/nodes/127.0.0.1`。
- SDK 证书来源：`/home/gstbk/fisco/nodes/127.0.0.1/sdk`。
- Java（编程语言运行环境）：OpenJDK 11。

常见启停命令按实际链目录调整：

```bash
cd /home/gstbk/fisco/nodes/127.0.0.1
bash start_all.sh
bash status.sh
bash stop_all.sh
```

console 示例：

```bash
cd "$FISCO_CONSOLE_DIR"
bash start.sh
```

真实 VM 验证记录见 `docs/evidence/fisco-contracts-phase1.md` 和 `docs/evidence/fisco-java-sdk-stage2.md`。

## Java SDK 与合约

链端合约在 `contracts/fisco-bcos/`：

- `PersonalInfo.sol`：身份密文和证明材料。
- `Signature.sol`：用户签名 JSON（JavaScript Object Notation，数据交换格式）。
- `Table.sol`：当前合约使用的最小 KVTable（键值表）接口。

Java SDK 调用层在 `chain-apps/fisco-bcos-java-sdk/`，当前已经包含：

- `PersonalInfo` 与 `Signature` 合约 wrapper（包装类）。
- `PersonalInfoClient` 与 `SignatureClient`。
- `info_run.sh` 与 `signature_run.sh`，兼容 Rust 侧历史脚本参数。
- `scripts/generate-contract-wrappers.sh`，用于合约变更后重新生成 wrapper。

准备真实链配置：

```bash
cd chain-apps/fisco-bcos-java-sdk
cp conf/config.toml.example conf/config.toml
mkdir -p conf/sdk conf/accounts
cp /home/gstbk/fisco/nodes/127.0.0.1/sdk/* conf/sdk/
```

真实 `conf/config.toml`、证书、私钥和账户文件禁止提交。

构建与链端调用示例：

```bash
export FISCO_CONFIG=conf/config.toml
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console

./gradlew clean build
./gradlew personalInfo --args="blockNumber"
./gradlew personalInfo --args="deploy"
./gradlew signature --args="deploy"
```

如果 VM 外网或 DNS（Domain Name System，域名系统）不可用，可预装 Gradle（构建工具）并设置：

```bash
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
```

## Rust 与链端脚本衔接

Rust 侧通过两个目录变量寻找链端包装脚本。当前推荐直接指向本仓库 Java SDK 调用层：

```bash
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...
```

目录要求：

- `GSTBK_PERSONAL_INFO_APP_DIR/info_run.sh` 用于写入或查询 `PersonalInfo` 合约。
- `GSTBK_SIGNATURE_APP_DIR/signature_run.sh` 用于写入或查询 `Signature` 合约。

包装脚本兼容旧参数：

```bash
bash chain-apps/fisco-bcos-java-sdk/info_run.sh register user1 /path/to/personal_info.json
bash chain-apps/fisco-bcos-java-sdk/info_run.sh select user1

bash chain-apps/fisco-bcos-java-sdk/signature_run.sh register user1 /path/to/signature_info.json
bash chain-apps/fisco-bcos-java-sdk/signature_run.sh select user1
```

`query` 仍是 `select` 的兼容别名。历史服务器路径仍可通过同一组变量覆盖，但新复现优先使用 `chain-apps/fisco-bcos-java-sdk`。

Rust 侧当前数据流如下：

1. User（用户）签名阶段生成 `signature_info.json`，调用 `GSTBK_SIGNATURE_APP_DIR/signature_run.sh register <user> <json>` 写入 `Signature` 合约。
2. User（用户）签名阶段读取已有 `personal_info.json`，调用 `GSTBK_PERSONAL_INFO_APP_DIR/info_run.sh register <user> <json>` 写入 `PersonalInfo` 合约。
3. Node（管理员节点）Verify（验证）阶段调用 `GSTBK_SIGNATURE_APP_DIR/signature_run.sh select <user>` 查询链上签名 JSON，再继续执行本地签名验证。
4. Java SDK 输出的 `ret`、`status`、`transactionHash`、`blockNumber`、`signature <json>` 或 `info <json>` 会进入 Rust 日志和标准输出，便于观察链端返回。

Rust 侧会在调用脚本前检查：

- `GSTBK_SIGNATURE_CONTRACT_ADDRESS` 或 `GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS` 不能为空，也不能保留全 `0x000...` 示例值。
- `GSTBK_SIGNATURE_APP_DIR` / `GSTBK_PERSONAL_INFO_APP_DIR` 下必须存在对应脚本；也兼容 `dist/signature_run.sh` 和 `dist/info_run.sh`。
- Java SDK 返回非零状态时，Rust 报错会保留 stdout（标准输出）和 stderr（标准错误）。

最小链端闭环可先直接验证脚本，再运行 Rust 多角色流程：

```bash
cd chain-apps/fisco-bcos-java-sdk
FISCO_CONFIG=conf/config.toml FISCO_GROUP=group0 ./signature_run.sh register user1 /path/to/signature_info.json
FISCO_CONFIG=conf/config.toml FISCO_GROUP=group0 ./signature_run.sh select user1
FISCO_CONFIG=conf/config.toml FISCO_GROUP=group0 ./info_run.sh register user1 /path/to/personal_info.json
FISCO_CONFIG=conf/config.toml FISCO_GROUP=group0 ./info_run.sh select user1
```

阶段 3 VM 复现中，如果 VM 外网或 Maven（Java 依赖仓库）不可用，设置 `FISCO_CONSOLE_DIR=/home/gstbk/fisco/console` 可直接使用 console 自带 `lib/*.jar`，避免 Gradle 下载依赖。

## Rust 构建检查

```bash
cargo fmt --all -- --check
cargo build --workspace
```

2026-05-11 VM 复现结果：`cargo check --workspace` 通过；本次触碰的 `id_info_process` Rust 文件通过 `rustfmt` 单文件检查；`cargo fmt --check` / `cargo fmt -p id_info_process --check` 仍会因历史 rustfmt 格式差异失败，详见 `docs/evidence/runtime-summary.md`。

## 一键编排

阶段 3.1 起，优先使用 `run-e2e.sh` 进行可重复冒烟验证：

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...

bash scripts/run-local/run-e2e.sh \
  --users 2 \
  --nodes 4 \
  --runtime-dir /tmp/gstbk-e2e-smoke \
  --reuse-chain \
  --contract-addresses-from-env
```

该脚本会调用 `render-configs.sh` 生成 local 配置，分别为 user1/user2 生成身份密文，启动 Proxy（代理）、Node（管理员节点）和 User（用户），等待 KeyGen（联合密钥生成）、Join（用户加入）、Sign（签名）、链上 register（登记）与 Open（揭示）关键日志，最后写出 `runtime-logs/<timestamp>/manifest.json`。local 与 multi-host 配置差异见 `scripts/run-local/README.md`。

## 控制台演示数据刷新

只读审计控制台不是纯静态页面：页面静态资源由 Node（JavaScript 运行时）服务托管，`/api/evidence` 会在每次请求时扫描本地 evidence JSON（JavaScript Object Notation，数据交换格式）摘要。因此，VM（Virtual Machine，虚拟机）上跑完新的 E2E（End-to-End，端到端）流程后，需要先刷新 JSON 摘要，再刷新浏览器页面。

在 `run-e2e.sh` 输出 `manifest /tmp/.../manifest.json` 后执行：

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --restart-service
```

该命令会生成并安装：

- `docs/evidence/console-current-audit-query.json`：当前链上只读审计查询批次。
- `docs/evidence/console-current-malicious-open.json`：当前 Verify/Open（验证/揭示）批次。

默认还会执行：

```bash
node apps/audit-console/server.mjs --check
```

如果控制台部署在单独目录，例如 `/opt/gs-tbk-audit-console`，可以显式指定部署根目录：

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --console-root /opt/gs-tbk-audit-console \
  --restart-service gstbk-audit-console
```

公网展示站不建议提供“点击按钮启动 E2E”的功能。需要演示动态流程时，推荐在 SSH（Secure Shell，安全外壳协议）终端运行 E2E 和刷新脚本，浏览器只负责展示刷新后的脱敏审计证据。

## 本地服务管理

阶段 3.6 起，优先使用 `gstbk-service.sh` 管理本地多角色进程。该脚本负责生成 runtime config（运行时配置）、保存 PID（Process Identifier，进程标识符）、写入 runtime logs（运行时日志）和 runtime state（运行时状态），并按 Proxy（代理）到 Node（管理员节点）再到 User（用户）的顺序调用正式 bin（二进制入口）。

```bash
bash scripts/run-local/gstbk-service.sh start all
bash scripts/run-local/gstbk-service.sh status all
bash scripts/run-local/gstbk-service.sh tail proxy
bash scripts/run-local/gstbk-service.sh stop all
```

默认 `all` 是 1 Proxy + 4 Node + 2 User 的 smoke（冒烟验证）拓扑。详细环境变量、目录布局和 VM（Virtual Machine，虚拟机）验收步骤见 [本地服务管理](service-supervision.md)。

## 手动启动顺序

多角色流程当前优先由正式 bin 入口驱动。若不使用服务管理脚本，建议每个角色使用独立终端。

1. 启动 Proxy：

```bash
bash scripts/run-local/run-proxy.sh
```

2. 启动 4 个 Node：

```bash
bash scripts/run-local/run-node.sh 1
bash scripts/run-local/run-node.sh 2
bash scripts/run-local/run-node.sh 3
bash scripts/run-local/run-node.sh 4
```

3. 运行身份字段 keygen（密钥生成）和 enc（加密证明），生成新的监管者密钥材料和可写链的身份密文 JSON：

```bash
export GSTBK_RUNTIME_DIR=/tmp/gstbk-e2e-smoke/runtime-state
export GSTBK_CL_KEYPAIR_PATH="$GSTBK_RUNTIME_DIR/cl_keypair.json"
bash scripts/run-local/run-id-info.sh keygen
GSTBK_ID_INFO_INPUT_PATH="$PWD/examples/id-info/user1.json" \
GSTBK_ID_INFO_OUTPUT_PATH="$GSTBK_RUNTIME_DIR/user1-block-personal-info.json" \
  bash scripts/run-local/run-id-info.sh enc
export GSTBK_PERSONAL_INFO_PAYLOAD_PATH="$GSTBK_RUNTIME_DIR/user1-block-personal-info.json"
```

`run-id-info.sh` 默认把 CL（Castagnos-Laguillaumie，同态加密方案）密钥写入 `runtime-state/cl_keypair.json`。`enc` 已改为正式 CLI（Command Line Interface，命令行接口）业务命令，支持 `--input <json>` 与 `--output <json>`，不再依赖 `cargo test` 作为业务入口。VM（Virtual Machine，虚拟机）冒烟验证可使用独立临时目录，避免污染仓库工作树：

```bash
export GSTBK_RUNTIME_DIR=/tmp/gstbk-rust-smoke/runtime-state
bash scripts/run-local/run-id-info.sh keygen
bash scripts/run-local/run-id-info.sh enc \
  --input examples/id-info/user1.json \
  --output "$GSTBK_RUNTIME_DIR/user1-block-personal-info.json"
bash scripts/run-local/run-id-info.sh verify \
  --input "$GSTBK_RUNTIME_DIR/user1-block-personal-info.json"
```

身份字段进入 CL（Castagnos-Laguillaumie，同态加密方案）前分两层处理：业务编码层保留 `encode_personal_info` 语义，输出“姓名 UTF-8（8 位统一码转换格式）十六进制 + 身份证 base36（36 进制）压缩串”；CL plaintext（明文）映射层再加 `GSTBK-ID-V1:` 版本前缀，把该 UTF-8 字节串解释为大整数并输出十进制字符串。`power_of_h_cpp` 只接受 `123`、`00123` 这类非空十进制整数，不能直接喂 hex/base36 业务编码，否则 C++ 原生库会抛异常并可能触发 native `SIGABRT`（进程中止信号）。Rust 侧在进入 CL native（原生库）前校验 `[0-9]+`，并提供 decimal plaintext 到 `IDInfo` 的可逆解码。

4. 启动至少 1 个 User，完整复现建议启动 `user1` 和 `user2`：

```bash
bash scripts/run-local/run-user.sh 1
bash scripts/run-local/run-user.sh 2
```

User 签名阶段会尝试调用 `signature_run.sh` 写入 `Signature` 合约；身份字段阶段会读取 `GSTBK_PERSONAL_INFO_PAYLOAD_PATH` 复制出的 `personal_info.json`，再调用 `info_run.sh` 写入 `PersonalInfo` 合约。若未设置合约地址或链端配置，协议本地阶段可能能运行，但链上登记会失败或停在脚本调用处。

## 旧 cargo test 命令

旧测试入口仍保留用于兼容调试，但 `run-proxy.sh`、`run-node.sh`、`run-user.sh` 和 `gstbk-service.sh` 默认不再走这些长运行测试入口。如需显式回退，可设置 `GSTBK_ROLE_ENTRYPOINT_MODE=test` 后再执行：

```bash
cargo test --package intergration_test --lib -- proxy::proxy_node::test --exact --nocapture
cargo test --package intergration_test --lib -- node::node1::node1::test --exact --nocapture
cargo test --package intergration_test --lib -- node::node2::node2::test --exact --nocapture
cargo test --package intergration_test --lib -- node::node3::node3::test --exact --nocapture
cargo test --package intergration_test --lib -- node::node4::node4::test --exact --nocapture
cargo test --package intergration_test --lib -- user::user1::user1::test --exact --nocapture
```

身份字段处理模块：

```bash
cargo run --package id_info_process --bin id_info_process -- keygen --output /tmp/cl_keypair.json
cargo run --package id_info_process --bin id_info_process -- enc --input examples/id-info/user1.json --output /tmp/user1-block-personal-info.json
cargo run --package id_info_process --bin id_info_process -- verify --input /tmp/user1-block-personal-info.json
```

测试入口仍保留用于质量门禁：

```bash
cargo test -p id_info_process
```

## 运行产物

历史运行状态和日志曾保存在 `crates/intergration_test/src/**/info/` 与 `logs/`。这些材料可用于理解流程，但不作为生产配置。新的运行日志、状态文件、证书、账户和密钥均应留在本地或 VM，被 `.gitignore` 排除。
