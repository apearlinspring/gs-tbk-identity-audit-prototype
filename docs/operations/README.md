# 运行手册

从准备 Linux 环境开始，依次构建 Rust、配置 Java SDK、部署或复用合约，再运行多角色 E2E。单独管理角色进程和更新审计台的步骤也列在下文。

## 运行环境

Rust 协议运行需要 Linux 环境，推荐 Ubuntu；依赖包括 `libencrypt.so`、GMP 和 PARI/GP。审计台可以单独在 Windows 或 Linux 上运行。

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

`.env.example` 统一记录 Proxy、Node、User、FISCO BCOS、Java SDK 和合约地址相关变量。文件权限与保存方式见 [secrets-and-config.md](secrets-and-config.md)。

## Java SDK 与合约

链端合约在 `contracts/fisco-bcos/`：

- `PersonalInfo.sol`：身份密文和证明材料。
- `Signature.sol`：用户签名 JSON。
- `Table.sol`：当前合约使用的最小 KVTable 接口。

Java SDK 调用层在 `chain-apps/fisco-bcos-java-sdk/`，包含 `PersonalInfo` / `Signature` 包装类、客户端、`info_run.sh`、`signature_run.sh` 和包装类生成脚本。

准备链端配置：

```bash
cd chain-apps/fisco-bcos-java-sdk
cp conf/config.toml.example conf/config.toml
mkdir -p conf/sdk conf/accounts
```

将目标节点的 SDK 证书放入 `conf/sdk/`，账户放入 `conf/accounts/`。

构建与链端调用示例：

```bash
export FISCO_CONFIG=conf/config.toml
export FISCO_GROUP=group0

./gradlew clean build
./gradlew personalInfo --args="deploy"
./gradlew signature --args="deploy"
```

如果目标环境已安装 FISCO BCOS console 并希望复用本地 jar 依赖，可设置：

```bash
export FISCO_CONSOLE_DIR=/path/to/fisco/console
```

## Rust 与链端脚本衔接

Rust 侧通过两个目录变量寻找链端包装脚本。推荐直接指向本仓库 Java SDK 调用层：

```bash
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...
```

包装脚本兼容旧参数：

```bash
bash chain-apps/fisco-bcos-java-sdk/info_run.sh register user1 /path/to/personal_info.json
bash chain-apps/fisco-bcos-java-sdk/info_run.sh select user1

bash chain-apps/fisco-bcos-java-sdk/signature_run.sh register user1 /path/to/signature_info.json
bash chain-apps/fisco-bcos-java-sdk/signature_run.sh select user1
```

Rust 侧会在调用脚本前检查合约地址和脚本路径；Java SDK 返回非零状态时，错误会保留标准输出和标准错误摘要。

## 构建检查

```bash
cargo fmt --all -- --check
cargo build --workspace
```

构建需要先设置上面的 `LD_LIBRARY_PATH`。

## E2E 编排

优先使用 `run-e2e.sh` 进行可重复冒烟验证：

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...

bash scripts/run-local/run-e2e.sh \
  --users 2 \
  --nodes 4 \
  --runtime-dir /tmp/gstbk-e2e-smoke \
  --reuse-chain \
  --contract-addresses-from-env
```

脚本生成本机配置和两个 User 的身份密文，按顺序启动角色，等待协议与链端结果，最后写出 `runtime-logs/<timestamp>/manifest.json`。配置选项见[本地运行脚本](../../scripts/run-local/README.md)。

## 控制台证据刷新

审计台通过 Node.js 读取本地 JSON 摘要。E2E 完成后，用 manifest 更新展示数据：

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json
```

该命令会生成并安装：

- `docs/evidence/console-current-audit-query.json`
- `docs/evidence/console-current-malicious-open.json`

这些文件已被 `.gitignore` 忽略，适合在服务器上反复覆盖。如需部署在单独目录，可使用：

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json \
  --console-root /opt/gs-tbk-audit-console \
  --restart-service gstbk-audit-console
```

页面刷新按钮只重新加载已安装的摘要。生成新证据时，在运行终端执行上述脚本。

## 本地服务管理

`gstbk-service.sh` 管理本地多角色进程，生成配置、保存 PID，并记录日志与状态：

```bash
bash scripts/run-local/gstbk-service.sh start all
bash scripts/run-local/gstbk-service.sh status all
bash scripts/run-local/gstbk-service.sh tail proxy
bash scripts/run-local/gstbk-service.sh stop all
```

默认 `all` 是 1 Proxy + 4 Node + 2 User 的演示拓扑。详细环境变量和目录布局见 [service-supervision.md](service-supervision.md)。

## 手动启动顺序

如果不使用服务管理脚本，建议每个角色使用独立终端。

```bash
bash scripts/run-local/run-proxy.sh
bash scripts/run-local/run-node.sh 1
bash scripts/run-local/run-node.sh 2
bash scripts/run-local/run-node.sh 3
bash scripts/run-local/run-node.sh 4
bash scripts/run-local/run-user.sh 1
```

身份字段 keygen、enc 和 verify 示例：

```bash
export GSTBK_RUNTIME_DIR=/tmp/gstbk-rust-smoke/runtime-state
bash scripts/run-local/run-id-info.sh keygen
bash scripts/run-local/run-id-info.sh enc \
  --input examples/id-info/user1.json \
  --output "$GSTBK_RUNTIME_DIR/user1-block-personal-info.json"
bash scripts/run-local/run-id-info.sh verify \
  --input "$GSTBK_RUNTIME_DIR/user1-block-personal-info.json"
```

## 运行产物

日志和状态默认写入运行目录；保存要求见[配置与密钥管理](secrets-and-config.md)，运行结果说明见[证据摘要](../evidence/runtime-summary.md)。
