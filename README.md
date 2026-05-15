# GS-TBK 分布式身份监管系统

本项目是一个基于 Rust（系统级编程语言）与 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）的分布式身份监管原型。它用多个 Node（管理员节点）的联合计算替代传统 PKI（Public Key Infrastructure，公钥基础设施）里的单点可信中心，让 User（用户）在保护身份隐私的前提下完成注册、匿名签名、验证、撤销和恶意用户揭示。

本仓库是公开展示版：保留主线 Rust workspace（工作区）、contracts（合约源码）、Java SDK（Software Development Kit，软件开发工具包）调用层、只读审计控制台、运行脚本、示例数据和可公开的 Markdown（轻量标记语言）证据摘要；不包含内部原始压缩包、第三方测试原件、真实证书、私钥、wallet（钱包）、keystore（密钥库）、`conf/config.toml`、运行大日志或未脱敏输入。

当前定位：本仓库是面向毕业设计、简历讲解和后续工程演进的可复现原型，不是完整生产系统。已经跑通 Rust + FISCO BCOS + CL（Castagnos-Laguillaumie，同态加密方案）身份字段加密/ZKP（Zero-Knowledge Proof，零知识证明）+ 多节点 E2E（End-to-End，端到端）+ 链上审计闭环；长期运行、自动部署和生产安全运维仍需单独建设。

## 项目能力

- GS-TBK（Group Signatures with Time-bound Keys，带时间绑定密钥的群签名方案）：支持用户匿名签名、时间绑定密钥、撤销和 Open（揭示）。
- CS-TBK（Complete Subtree with Time-bound Keys，带时间绑定密钥的完整子树算法）：用于撤销集合和时间树相关处理。
- CL（Castagnos-Laguillaumie，同态加密方案）身份字段处理：对姓名、证件号等字段进行编码、加密、证明和解密验证。
- VSS（Verifiable Secret Sharing，可验证秘密共享）与 MtA（Multiplicative-to-Additive，乘法转加法分享协议）：支撑多节点联合密钥生成和协议阶段计算。
- ZKP（Zero-Knowledge Proof，零知识证明）：用于证明密文、承诺和身份字段关系。
- FISCO BCOS 链端登记：`PersonalInfo` 合约保存身份密文/证明材料，`Signature` 合约保存用户签名 JSON（JavaScript Object Notation，数据交换格式）。

## 目录结构

```text
.
├── crates/                 # 主线 Rust workspace 代码
│   ├── class_group/         # 类群、CL 同态加密和证明工具
│   ├── gs_tbk_scheme/       # GS-TBK 公共参数、消息和时间树
│   ├── proxy/               # Proxy（代理）角色
│   ├── node/                # Node（管理员节点）角色
│   ├── user/                # User（用户）角色
│   ├── intergration_test/   # 多角色集成测试入口，保留历史拼写
│   ├── cl_encrypt/          # CL 原生库 Rust FFI（Foreign Function Interface，外部函数接口）封装
│   └── id_info_process/     # 身份字段编码、加密、证明和解密验证
├── contracts/              # FISCO BCOS Solidity（智能合约编程语言）合约
├── chain-apps/             # FISCO BCOS Java SDK 调用层
├── apps/                   # 只读审计控制台等辅助应用
├── scripts/                # 本地/VM 运行脚本和辅助入口
├── docs/                   # 架构、部署、运行、计划和证据文档
├── examples/               # 示例输入和参考 demo
├── .env.example            # Rust 与链端集成环境变量模板
├── Cargo.toml              # Rust workspace 配置
├── Cargo.lock              # v2.9 主线锁定文件，已随阶段 3 VM（Virtual Machine，虚拟机）复现复核
└── AGENTS.md               # 项目协作备忘
```

## 模块关系

Rust 侧负责协议主体，链端负责登记和查询：

- `crates/proxy`：维护 Proxy 地址、时间树、门限参数、群公钥、节点和用户信息。
- `crates/node`：维护 DKG（Distributed Key Generation，分布式密钥生成）材料、密钥碎片、注册/撤销状态，并在 Verify（验证）和 Open 阶段读取链上签名。
- `crates/user`：生成用户私钥、身份密文、签名材料，并通过脚本调用链端应用。
- `contracts/fisco-bcos`：保存 `PersonalInfo.sol`、`Signature.sol` 和最小 `Table.sol` 接口。
- `chain-apps/fisco-bcos-java-sdk`：用 Java SDK 调用合约，已包含 `PersonalInfo` / `Signature` wrapper（包装类）、客户端和 `info_run.sh` / `signature_run.sh` 包装脚本。
- `apps/audit-console`：只读 Web（网页）/API（Application Programming Interface，应用程序接口）审计控制台，从仓库内 evidence JSON（JavaScript Object Notation，数据交换格式）摘要聚合用户、合约、交易、Verify/Open（验证/揭示）和失败场景展示，不连接真实链端；VM（Virtual Machine，虚拟机）跑完 E2E（End-to-End，端到端）后可通过 `scripts/evidence/refresh-audit-console-evidence.sh` 刷新当前展示数据。
- `scripts/run-local`：对常用 `cargo test` 入口做薄封装，便于按角色启动。

更完整的数据流见 [docs/architecture.md](docs/architecture.md)。

## 当前状态

已经完成：

- 主线 Rust workspace、身份字段处理模块和 CL 原生库封装。
- `PersonalInfo.sol`、`Signature.sol` 已在 FISCO BCOS v3.6.0 VM（Virtual Machine，虚拟机）环境完成编译、部署和调用验证，证据见 [docs/evidence/fisco-contracts-phase1.md](docs/evidence/fisco-contracts-phase1.md)。
- Java SDK 调用层已包含 wrapper、客户端、Gradle（构建工具）配置和兼容 Rust 侧的包装脚本，VM 闭环证据见 [docs/evidence/fisco-java-sdk-stage2.md](docs/evidence/fisco-java-sdk-stage2.md)。
- Rust 到链端的生产化 smoke 验证已经跑通：1 个 Proxy（代理）+ 4 个 Node（管理员节点）+ 2 个 User（用户）完成 KeyGen（联合密钥生成）、Join（用户加入）、Revoke（撤销）、Sign（签名）、链上 register（登记）、Node select（查询）、Verify（验证）和 Open（揭示），证据见 [docs/evidence/runtime-summary.md](docs/evidence/runtime-summary.md) 与 [docs/evidence/e2e-merge-readiness.md](docs/evidence/e2e-merge-readiness.md)。
- 本地启动脚本、一键 E2E 编排脚本、运行命令说明、运行证据摘要。
- 只读 Web（网页）/API（Application Programming Interface，应用程序接口）审计控制台已经形成演示入口，可聚合已提交的 JSON 摘要和 `events[]` 事件样例；它不连接真实链端，也不读取证书、私钥、wallet、keystore 或 `conf/config.toml`。VM 演示时可先运行 E2E，再用 `refresh-audit-console-evidence.sh` 把最新 manifest 转成 `console-current-*` 当前证据批次。
- `.env.example` 和 `.gitignore`，用于统一环境变量并阻止真实证书、私钥、账户文件、`conf/config.toml`、运行日志和状态文件入库。
- CI（Continuous Integration，持续集成）基础骨架和 [docs/architecture.md](docs/architecture.md) 架构说明。

生产化 smoke 验证摘要：

| 项目 | 记录 |
| --- | --- |
| 基线 tag（标签） | `e2e-baseline-2026-05-11` |
| 环境 | `gstbk-vm` / Ubuntu 22.04.4 LTS / FISCO BCOS v3.6.0 |
| 编排 | `run-e2e.sh --users 2 --nodes 4 --reuse-chain --contract-addresses-from-env` |
| 规模 | 1 Proxy + 4 Node + 2 User |
| 区块高度 | `30` -> `34` |
| `Signature` 交易 | user1：`0x929e6b566d2b95cf09d278a925c8494a6da6017606c61e007ede1554fc7369f8`，区块 `31`；user2：`0xd8b364623a97c07422123968e79d7ce8324b08605c06e4765e321b3e0fb19a8e`，区块 `32` |
| `PersonalInfo` 交易 | user1：`0x66aeaa0a862d3d0c0b2f44819805ab2424fe557f814da4d63b021a1b62aa5e47`，区块 `33`；user2：`0x75c965e4f3f5ac54d12046204db3e4b328236b29cf7248ffd017793a68e99303`，区块 `34` |
| 查询与审计 | 两类合约均 `exists true`；4 个 Node 均完成 Verify/Open |

仍非生产级能力：

- 多角色正式入口仍复用 `crates/intergration_test` 中已验证的协议流程模块，适合 smoke 验证和工程原型运行；`gstbk-service.sh` 是本地 service supervisor（服务管理器），还不是 systemd（Linux 系统服务管理器）或容器平台。
- runtime（运行时）配置隔离已默认不写回 legacy fixture（历史夹具）路径，但生产部署仍需要更完整的多环境配置分层。
- CI（Continuous Integration，持续集成）已有基础强门禁，但不持有真实链端配置，也不替代 VM（Virtual Machine，虚拟机）E2E 验收。
- FISCO BCOS 运维脚本已有 doctor（环境健康检查）、配置准备和合约部署/复用基础能力；生产级安全配置治理、自动化部署、链节点运维和密钥轮换仍需继续建设。

## 快速开始

推荐在 Ubuntu 或 VM 中运行。Windows（微软操作系统）更适合做资料整理和静态编辑，`libencrypt.so` 以及类群依赖需要 Linux 原生环境验证。

1. 准备依赖：

```bash
sudo apt-get update
sudo apt-get install -y build-essential pkg-config libgmp-dev pari-gp libpari-dev bison clang libclang-dev
```

2. 准备环境变量：

```bash
cp .env.example .env
set -a
. ./.env
set +a
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"
```

3. 构建或检查 Rust 主线：

```bash
cargo fmt --all -- --check
cargo build --workspace
```

4. 如需接入链端，准备 FISCO BCOS 节点、`chain-apps/fisco-bcos-java-sdk/conf/config.toml`、证书、账户文件和合约地址。真实配置和密钥文件禁止提交。Rust 侧推荐指向本仓库包装脚本：

```bash
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...
```

5. 按顺序启动协议角色：

```bash
bash scripts/run-local/run-proxy.sh
bash scripts/run-local/run-node.sh 1
bash scripts/run-local/run-node.sh 2
bash scripts/run-local/run-node.sh 3
bash scripts/run-local/run-node.sh 4
bash scripts/run-local/run-user.sh 1
```

6. 身份字段流程：

```bash
bash scripts/run-local/run-id-info.sh keygen
bash scripts/run-local/run-id-info.sh enc
```

详细启动顺序、VM 路径、FISCO BCOS 启停和 Java SDK 衔接方式见 [docs/operations/README.md](docs/operations/README.md) 与 [scripts/run-local/README.md](scripts/run-local/README.md)。

## 文档入口

- [docs/README.md](docs/README.md)：文档总索引。
- [docs/releases/v0.1-engineering-prototype.md](docs/releases/v0.1-engineering-prototype.md)：v0.1 工程原型发布说明、最短复现路径、验收 checklist（检查清单）和面试讲解口径。
- [docs/releases/v0.2-auditable-prototype.md](docs/releases/v0.2-auditable-prototype.md)：v0.2 可审计工程原型发布说明，覆盖失败场景、审计查询、恶意揭示和 JSON（JavaScript Object Notation，数据交换格式）摘要。
- [docs/releases/v0.3-demo-console.md](docs/releases/v0.3-demo-console.md)：v0.3 演示控制台发布说明，覆盖只读 Web（网页）/API（Application Programming Interface，应用程序接口）审计控制台、`events[]` 事件样例和 AI（Artificial Intelligence，人工智能）安全桥接。
- [apps/audit-console/README.md](apps/audit-console/README.md)：只读审计控制台说明，最短演示路径为 `npm run check`、`npm start`、`http://127.0.0.1:4173` 和 VM 演示数据刷新命令。
- [docs/demo/audit-console-demo.md](docs/demo/audit-console-demo.md)：身份监管审计台现场演示 Runbook（运行手册），覆盖公网展示、VM（Virtual Machine，虚拟机）内网展示、DNS（Domain Name System，域名系统）注意事项和讲解顺序。
- [docs/interview/project-walkthrough.md](docs/interview/project-walkthrough.md)：面试讲解包，覆盖展示入口、2 分钟概述、5 分钟技术结构、深挖问答和边界。
- [docs/interview/resume-bullets.md](docs/interview/resume-bullets.md)：AI 应用开发和 AI 安全两套简历 bullet（项目符号）与不能写的夸大表述。
- [docs/architecture.md](docs/architecture.md)：系统角色、链端集成和数据流。
- [docs/operations/README.md](docs/operations/README.md)：本地/VM 运行路径和启动顺序。
- [scripts/run-local/README.md](scripts/run-local/README.md)：脚本参数和调用方式。
- [docs/evidence/README.md](docs/evidence/README.md)：测试证据和可信度边界。
- [docs/plans/project-optimization-plan.md](docs/plans/project-optimization-plan.md)：阶段化优化计划。
