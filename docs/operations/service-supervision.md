# 本地服务管理

`scripts/run-local/gstbk-service.sh` 提供本地 service supervisor（服务管理器）能力，用于管理 Proxy（代理）、Node（管理员节点）和 User（用户）的长期运行进程。它只编排现有正式 bin（二进制入口）和本地脚本，不修改协议逻辑，也不重构密码学代码。

## 准备

在 VM（Virtual Machine，虚拟机）或 Linux（操作系统内核）环境中从仓库根目录执行：

```bash
set -a
. ./.env
set +a
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
```

如果需要链上写入，还要先准备 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）和 Java SDK（Software Development Kit，软件开发工具包）真实配置：

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...
```

真实 `conf/config.toml`、证书、账户、wallet（钱包）、keystore（密钥库）和私钥只保留在本地或 VM，不提交 Git（分布式版本控制系统）。

## Runtime 目录

默认 runtime（运行时）根目录为：

```text
runtime-state/service-supervision/
```

目录布局：

```text
runtime-state/service-supervision/
├── pids/             # PID（Process Identifier，进程标识符）文件
├── runtime-logs/     # 角色日志、启动命令、身份字段处理日志
├── runtime-config/   # Proxy/Node/User 运行配置
└── runtime-state/    # Node/User info、身份密文、CL 密钥材料
```

可通过 `GSTBK_SERVICE_RUNTIME_DIR` 改到 `/tmp/gstbk-service-supervision` 等临时目录。若只想复用已生成配置，可设置 `GSTBK_SERVICE_RENDER_CONFIGS=0`，同时确保 `GSTBK_SERVICE_CONFIG_DIR` 或默认 `runtime-config/` 已存在。

## 常用命令

默认 `all` 拓扑是 1 个 Proxy、4 个 Node 和 2 个 User：

```bash
bash scripts/run-local/gstbk-service.sh start all
bash scripts/run-local/gstbk-service.sh status all
bash scripts/run-local/gstbk-service.sh tail proxy
bash scripts/run-local/gstbk-service.sh stop all
```

单角色管理：

```bash
bash scripts/run-local/gstbk-service.sh start proxy
bash scripts/run-local/gstbk-service.sh restart node 1
bash scripts/run-local/gstbk-service.sh status user 2
bash scripts/run-local/gstbk-service.sh tail node 4 --lines 120
bash scripts/run-local/gstbk-service.sh tail user 1 --follow
```

关键环境变量：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `GSTBK_SERVICE_NODES` | `4` | `all` 启动的 Node 数量，范围 `1..4`。 |
| `GSTBK_SERVICE_USERS` | `2` | `all` 启动的 User 数量，范围 `1..6`。 |
| `GSTBK_SERVICE_HOST` | `127.0.0.1` | 渲染到配置中的互访地址。 |
| `GSTBK_SERVICE_LISTEN_HOST` | `0.0.0.0` | 本地监听地址。 |
| `GSTBK_SERVICE_PROXY_PORT` | `50000` | Proxy 端口。 |
| `GSTBK_SERVICE_NODE_PORT_START` | `50001` | Node 起始端口。 |
| `GSTBK_SERVICE_USER_PORT_START` | `60001` | User 起始端口。 |
| `GSTBK_SERVICE_START_TIMEOUT_SECONDS` | `300` | 等待角色端口监听的启动超时。 |
| `GSTBK_SERVICE_WAIT_FOR_KEYGEN` | `1` | `all` 启动 User 前等待 Proxy KeyGen（联合密钥生成）完成。 |
| `GSTBK_SERVICE_GENERATE_IDENTITY` | `1` | 为有样例输入的 User 自动生成身份密文。 |
| `GSTBK_SERVICE_ROLE_ENTRYPOINT_MODE` | `bin` | 传给角色脚本的入口模式，默认固定正式 bin（二进制入口）。 |

当前仓库只内置 `examples/id-info/user1.json` 和 `examples/id-info/user2.json`。启动 `user3` 到 `user6` 时，建议显式提供独立身份密文：

```bash
export GSTBK_USER3_PERSONAL_INFO_PAYLOAD_PATH=/tmp/user3-block-personal-info.json
bash scripts/run-local/gstbk-service.sh start user 3
```

## VM 验收

在 VM 上完成 FISCO BCOS 和 Java SDK 配置后，执行基础检查：

```bash
bash -n scripts/run-local/*.sh scripts/fisco/*.sh
cargo fmt --all -- --check
LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}" cargo check --workspace --locked
```

启动和观察：

```bash
bash scripts/run-local/gstbk-service.sh start all
bash scripts/run-local/gstbk-service.sh status all
bash scripts/run-local/gstbk-service.sh tail proxy
```

停止并复核端口：

```bash
bash scripts/run-local/gstbk-service.sh stop all

for port in 50000 50001 50002 50003 50004 60001 60002; do
  if ss -ltnH | awk '{print $4}' | grep -Eq "(^|:)$port$"; then
    echo "still listening: $port"
  fi
done
```

停止后不应输出残留端口。若 `status all` 显示 stale（过期）PID，先执行 `stop all` 清理 PID 文件，再确认没有外部进程占用对应端口。
