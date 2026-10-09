# GS-TBK 分布式身份监管系统

基于 Rust 和 FISCO BCOS 的身份监管工程原型。多个管理员节点协作完成密钥生成、成员注册和群签名揭示，身份密文与签名记录保存在链上，便于后续查询和追溯。

项目包含 GS-TBK 时间绑定群签名、CL 身份字段加密与零知识证明，以及一个展示运行摘要的审计台。2026 年 5 月的虚拟机验证跑通了 1 个 Proxy、4 个 Node、2 个 User 的协议与链端调用流程，记录见 [运行证据摘要](docs/evidence/runtime-summary.md)。

## 架构

| 模块 | 职责 |
| --- | --- |
| `crates/proxy` | 协调协议阶段，维护时间树、群公钥和节点、用户信息。 |
| `crates/node` | 执行联合密钥生成、成员发证、验签与 Open 揭示。 |
| `crates/user` | 生成成员密钥与群签名，调用链端脚本登记签名和身份密文。 |
| `crates/id_info_process`、`crates/cl_encrypt` | 身份字段编码、CL 加密、证明生成与验证。 |
| `contracts/fisco-bcos` | `PersonalInfo` 保存身份密文和证明，`Signature` 保存签名记录。 |
| `chain-apps/fisco-bcos-java-sdk` | Java SDK 合约调用层，提供 Rust 使用的脚本入口。 |
| `apps/audit-console` | 读取本地证据摘要，展示交易、查询与 Verify/Open 结果。 |

角色进程通过 `crates/intergration_test` 中的 `gstbk-proxy`、`gstbk-node` 和 `gstbk-user` 启动。完整数据流见 [架构说明](docs/architecture.md)。

## 运行

协议和身份加密模块需要 Linux，推荐 Ubuntu。除 Rust、Java 11 和 Gradle 外，还需要 GMP、PARI/GP 等原生依赖，`libencrypt.so` 也需要 Linux 环境。审计台可以单独在 Windows 或 Linux 上运行。

### 构建 Rust

在仓库根目录执行：

```bash
sudo apt-get update
sudo apt-get install -y build-essential pkg-config libgmp-dev pari-gp libpari-dev bison clang libclang-dev

cp .env.example .env
set -a
. ./.env
set +a
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"

cargo fmt --all -- --check
cargo build --workspace
```

### 身份字段处理

```bash
bash scripts/run-local/run-id-info.sh keygen
bash scripts/run-local/run-id-info.sh enc --input examples/id-info/user1.json
bash scripts/run-local/run-id-info.sh verify
```

`enc` 输出密文、承诺和证明，`verify` 验证证明。监管者解密身份的流程尚未接入 Open 运行链路。

### 连接 FISCO BCOS

先准备运行中的链、Java SDK 的 `conf/config.toml`、证书、账户和两个合约地址：

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...

bash scripts/run-local/run-e2e.sh \
  --users 2 \
  --nodes 4 \
  --runtime-dir /tmp/gstbk-e2e-smoke \
  --reuse-chain \
  --contract-addresses-from-env
```

E2E 脚本生成独立运行配置和身份密文，依次启动角色，查询链上记录，并保存日志与 manifest。手动启动和服务管理见 [运行说明](docs/operations/README.md)，链端环境准备见 [FISCO 运维手册](docs/operations/fisco-runbook.md)。

### 审计台

需要 Node.js 18 或更新版本，无额外 npm 依赖：

```bash
cd apps/audit-console
npm run check
npm start
```

打开 `http://127.0.0.1:4173`。页面读取本地 JSON 摘要，不直接查询链；初始数据是示例事件。E2E 完成后，在仓库根目录刷新展示数据：

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json
```

生成的 `docs/evidence/console-current-*` 文件供本地展示使用，已加入 `.gitignore`。更多参数见 [审计台说明](apps/audit-console/README.md)。

## 验证与使用范围

CI 检查 Rust 格式和构建、Java 构建、脚本与前端语法、合约接口一致性及摘要读取。连接真实链的多角色 E2E 需在部署环境中另行运行，历史验证记录集中在 [docs/evidence](docs/evidence/README.md)。

当前项目用于协议复现与演示。链上的签名记录带有协议用户编号和名称，Open 的输出来自本地注册表；合约负责存储，签名和证明由 Rust 验证。长期服务的权限、监控和密钥运维仍需补齐。

证书、私钥与运行配置放在部署环境中，具体路径和权限见 [配置说明](docs/operations/secrets-and-config.md)。[文档索引](docs/README.md) 汇总了模块、运行脚本和验证资料。
