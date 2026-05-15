# VM 访问与 FISCO BCOS 环境

本文记录当前项目使用的 VM（Virtual Machine，虚拟机）访问方式、FISCO BCOS（金融区块链合作联盟开源区块链底层平台）路径和验证边界。后续需要 VM 的任务优先阅读本文，不再在 prompt（提示词）中重复写连接信息。

## 连接信息

| 字段 | 值 |
| --- | --- |
| SSH alias（别名） | `gstbk-vm` |
| IP（Internet Protocol，互联网协议地址） | `192.168.1.24` |
| User（用户） | `gstbk` |
| OS（Operating System，操作系统） | Ubuntu 22.04.4 LTS |
| 主机名线索 | `gs-tbk-dev` |
| 用途 | FISCO BCOS 链端验证、Rust Linux 构建、E2E（End-to-End，端到端）/service smoke（服务冒烟验证） |

推荐本机 SSH config（配置）：

```sshconfig
Host gstbk-vm
  HostName 192.168.1.24
  User gstbk
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

连接检查：

```bash
ssh gstbk-vm 'whoami; hostname -I; uname -a'
```

不要把 SSH 私钥、密码、token（令牌）或任何真实凭据写入仓库。

## FISCO BCOS 环境

| 字段 | 值 |
| --- | --- |
| FISCO BCOS 版本 | v3.6.0 |
| Group（组） | `group0` |
| 节点目录 | `/home/gstbk/fisco/nodes/127.0.0.1` |
| console（控制台）目录 | `/home/gstbk/fisco/console` |
| SDK 证书来源 | `/home/gstbk/fisco/nodes/127.0.0.1/sdk` |
| Java / Gradle | OpenJDK 11.0.30 / Gradle 8.10.2 |
| 常用节点端口 | `20200`、`20201`、`30300`、`30301` |
| Proxy/Node/User 端口 | Proxy `50000`，Node `50001` 到 `50004`，User `60001` 到 `60006` |

当前基线合约：

| 合约 | 地址 |
| --- | --- |
| `PersonalInfo` | `0x6546c3571f17858ea45575e7c6457dad03e53dbb` |
| `Signature` | `0xcceef68c9b4811b32c75df284a1396c7c5509561` |

常用环境变量：

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x6546c3571f17858ea45575e7c6457dad03e53dbb
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0xcceef68c9b4811b32c75df284a1396c7c5509561
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"
```

真实 `conf/config.toml`、SDK 证书、账户、wallet（钱包）、keystore（密钥库）和私钥只保留在 VM 或本机安全目录，不提交 Git（分布式版本控制系统）。敏感边界见 [敏感材料与配置边界](secrets-and-config.md)。

## 推荐工作目录

VM 验证应使用 `/tmp` 下的独立目录，避免污染主目录和其他任务：

```text
/tmp/gstbk-<task-name>-verify
/tmp/gstbk-<task-name>-runtime
/tmp/gstbk-<task-name>-logs
```

示例同步方式：

```bash
git bundle create ../gs_tbk-task.bundle HEAD
scp ../gs_tbk-task.bundle gstbk-vm:/tmp/
ssh gstbk-vm 'rm -rf /tmp/gstbk-task-verify && git clone /tmp/gs_tbk-task.bundle /tmp/gstbk-task-verify'
```

如果当前任务需要真实 `conf/config.toml` 和证书，进入 VM 后在临时仓库中运行：

```bash
cd /tmp/gstbk-task-verify
bash scripts/fisco/prepare-sdk-conf.sh \
  --node-sdk-dir /home/gstbk/fisco/nodes/127.0.0.1/sdk \
  --app-dir "$PWD/chain-apps/fisco-bcos-java-sdk" \
  --group group0 \
  --peers 127.0.0.1:20200,127.0.0.1:20201 \
  --force
```

## 常用验证命令

链端健康检查：

```bash
cd /tmp/gstbk-task-verify
bash scripts/fisco/doctor.sh
```

Rust 构建检查：

```bash
cd /tmp/gstbk-task-verify
cargo fmt --all -- --check
LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}" cargo check --workspace --locked
```

如需验证 Rust build（构建）门禁：

```bash
LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}" cargo build --workspace --locked
```

E2E smoke：

```bash
bash scripts/run-local/run-e2e.sh \
  --users 2 \
  --nodes 4 \
  --runtime-dir /tmp/gstbk-e2e-smoke \
  --reuse-chain \
  --contract-addresses-from-env \
  --timeout-seconds 300
```

Service smoke：

```bash
export GSTBK_SERVICE_RUNTIME_DIR=/tmp/gstbk-service-smoke
bash scripts/run-local/gstbk-service.sh start all
bash scripts/run-local/gstbk-service.sh status all
bash scripts/run-local/gstbk-service.sh stop all
```

## 安全与协作边界

- 除非明确确认没有其他任务在跑，不要停止 FISCO BCOS 节点，不要重建链，不要清空链数据。
- 复用当前基线合约优先；只有部署任务明确要求时才部署新合约。
- 不要提交 VM 上的真实配置、证书、账户、wallet、keystore、私钥、运行日志或 runtime state（运行时状态）。
- 多个 agent（代理协作者）并行时，使用独立 `/tmp/gstbk-*-runtime` 和 `/tmp/gstbk-*-verify` 目录。
- 如果 VM 网络或 DNS（Domain Name System，域名系统）不稳定，优先复用 `FISCO_CONSOLE_DIR=/home/gstbk/fisco/console` 的本地 jar（Java 归档文件）依赖；需要临时代理时再单独说明，不把代理凭据写入仓库。
