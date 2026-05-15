# 本地运行脚本

本目录整理 Rust（系统级编程语言）侧常用启动命令。脚本默认从仓库根目录执行，不会改写真实链端配置或证书文件。

## 准备

```bash
cd /path/to/gs_tbk_wt_e2e
cp .env.example .env
set -a
. ./.env
set +a
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"
```

单机复现时，Proxy（代理）、Node（管理员节点）和 User（用户）的本地配置应使用 `127.0.0.1` 端口矩阵：Proxy `50000`，Node `50001` 到 `50004`，User `60001` 到 `60006`。多机运行时再改为实际内网 IP（Internet Protocol，互联网协议地址）。

## 身份字段加密流程

```bash
bash scripts/run-local/run-id-info.sh keygen
bash scripts/run-local/run-id-info.sh enc \
  --input examples/id-info/user1.json \
  --output /tmp/gstbk-e2e-smoke/runtime-state/user1-block-personal-info.json
bash scripts/run-local/run-id-info.sh verify \
  --input /tmp/gstbk-e2e-smoke/runtime-state/user1-block-personal-info.json
```

`keygen` 会生成 CL（Castagnos-Laguillaumie，同态加密方案）监管者密钥，默认写入 `runtime-state/cl_keypair.json`，可通过 `GSTBK_CL_KEYPAIR_PATH` 覆盖。

`enc` 会调用 `id_info_process` 正式 CLI（Command Line Interface，命令行接口），执行身份字段编码、CL 加密和 ZKP（Zero-Knowledge Proof，零知识证明）生成。`verify` 会复核密文证明。设置 `GSTBK_RUNTIME_DIR` 时，默认输出为：

```text
$GSTBK_RUNTIME_DIR/block_personal_info.json
```

该文件可作为 `PersonalInfo` 合约写链输入，也可通过 `GSTBK_PERSONAL_INFO_PAYLOAD_PATH` 注入到 User 流程。阶段 3.1 起不再让多个 User 复用同一份身份密文，示例输入位于 `examples/id-info/user1.json` 和 `examples/id-info/user2.json`：

```bash
export GSTBK_RUNTIME_DIR=/tmp/gstbk-e2e-smoke/runtime-state
export GSTBK_CL_KEYPAIR_PATH="$GSTBK_RUNTIME_DIR/cl_keypair.json"
bash scripts/run-local/run-id-info.sh keygen

GSTBK_ID_INFO_INPUT_PATH="$PWD/examples/id-info/user1.json" \
GSTBK_ID_INFO_OUTPUT_PATH="$GSTBK_RUNTIME_DIR/user1-block-personal-info.json" \
  bash scripts/run-local/run-id-info.sh enc

GSTBK_ID_INFO_INPUT_PATH="$PWD/examples/id-info/user2.json" \
GSTBK_ID_INFO_OUTPUT_PATH="$GSTBK_RUNTIME_DIR/user2-block-personal-info.json" \
  bash scripts/run-local/run-id-info.sh enc
```

## 配置渲染

`crates/intergration_test` 仍保留一组 local smoke fixture（本机冒烟验证夹具）配置，默认使用 `127.0.0.1`。`render-configs.sh` 默认写 legacy fixture（历史夹具）路径；推荐在 E2E（End-to-End，端到端）编排中输出到 runtime（运行时）配置目录，避免写回 Git（分布式版本控制系统）工作树：

```bash
bash scripts/run-local/render-configs.sh \
  --mode local \
  --nodes 4 \
  --users 2 \
  --host 127.0.0.1 \
  --output-dir /tmp/gstbk-e2e-smoke/runtime-state/20260511T000000Z/runtime-config
```

也可以先设置 `GSTBK_RUNTIME_CONFIG_DIR`，再运行渲染脚本；输出目录结构为 `proxy/proxy_config.json`、`node/nodeN/node_config.json` 和 `user/userN/user_config.json`。未设置 `--output-dir` 或 `GSTBK_RUNTIME_CONFIG_DIR` 时，脚本保持兼容行为，写入 `crates/intergration_test/src/**/config/config_file/*.json`。

多机或 VM 内网运行时，将 `--host` 改成实际可互通的内网 IP：

```bash
bash scripts/run-local/render-configs.sh \
  --mode multi-host \
  --host 192.168.1.24 \
  --nodes 4 \
  --users 2 \
  --output-dir /tmp/gstbk-e2e-smoke/runtime-state/20260511T000000Z/runtime-config
```

local 模式只适合单机进程矩阵；multi-host 模式只负责渲染角色互相访问的地址，仍需要自行保证防火墙、端口和多机文件分发一致。

## 本地服务管理

`gstbk-service.sh` 是本地 service supervisor（服务管理器），用于把 Proxy（代理）、Node（管理员节点）和 User（用户）按长期运行进程管理。它默认设置 `GSTBK_ROLE_ENTRYPOINT_MODE=bin` 并调用正式 bin（二进制入口），不回退到 `cargo test` 长运行入口。

默认 runtime（运行时）根目录为 `runtime-state/service-supervision/`，其中包含：

- `pids/`：PID（Process Identifier，进程标识符）文件。
- `runtime-logs/`：角色日志、启动命令和身份字段处理日志。
- `runtime-config/`：由 `render-configs.sh` 生成的 runtime config（运行时配置）。
- `runtime-state/`：Node/User 运行态、身份密文和 CL 密钥材料。

常用命令：

```bash
bash scripts/run-local/gstbk-service.sh start all
bash scripts/run-local/gstbk-service.sh status all
bash scripts/run-local/gstbk-service.sh tail proxy
bash scripts/run-local/gstbk-service.sh stop all
```

也可以管理单个角色：

```bash
bash scripts/run-local/gstbk-service.sh restart proxy
bash scripts/run-local/gstbk-service.sh start node 1
bash scripts/run-local/gstbk-service.sh status user 2
bash scripts/run-local/gstbk-service.sh tail node 4 --lines 120
bash scripts/run-local/gstbk-service.sh tail user 1 --follow
```

`all` 默认启动当前 smoke（冒烟验证）拓扑：1 个 Proxy、4 个 Node、2 个 User。需要启动更多 User 时可设置 `GSTBK_SERVICE_USERS=6`，但 `examples/id-info/` 当前只内置 `user1.json` 和 `user2.json`；`user3` 到 `user6` 应通过 `GSTBK_USER3_PERSONAL_INFO_PAYLOAD_PATH` 这类变量提供独立身份密文 JSON（JavaScript Object Notation，数据交换格式），或提前把 `personal_info.json` 放入对应 runtime state（运行时状态）目录。

默认启动 User 1/2 时，服务脚本会在 runtime state 中生成 CL（Castagnos-Laguillaumie，同态加密方案）监管者密钥和身份密文，并把每个 User 的密文通过 `GSTBK_PERSONAL_INFO_PAYLOAD_PATH` 注入 `run-user.sh`。如需完全手工提供身份密文，可设置：

```bash
export GSTBK_SERVICE_GENERATE_IDENTITY=0
export GSTBK_USER1_PERSONAL_INFO_PAYLOAD_PATH=/tmp/user1-block-personal-info.json
export GSTBK_USER2_PERSONAL_INFO_PAYLOAD_PATH=/tmp/user2-block-personal-info.json
```

首次在新 VM 目录中执行时，`cargo run` 可能还需要补编译角色 bin；服务脚本默认最多等待角色端口 300 秒，可通过 `GSTBK_SERVICE_START_TIMEOUT_SECONDS` 调整。

更多运行和 VM（Virtual Machine，虚拟机）验收步骤见 `docs/operations/service-supervision.md`。

## 一键 E2E 编排

`run-e2e.sh` 会完成端口占用检查、配置渲染、身份字段 keygen/enc/verify、启动 1 Proxy + N Node + M User、等待关键日志、链上 select 复核、失败尾日志打印、后台进程清理和 manifest 生成：

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
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

`--reuse-chain` 表示复用已运行的 FISCO BCOS 链，脚本会先执行 `blockNumber` 健康检查；当前脚本不负责启动或重建链，未传 `--reuse-chain` 会提前报错。

运行前必须显式设置 `FISCO_CONFIG`、`FISCO_GROUP`、`GSTBK_PERSONAL_INFO_APP_DIR` 和 `GSTBK_SIGNATURE_APP_DIR`。使用 `--contract-addresses-from-env` 时，还必须设置 `GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS` 和 `GSTBK_SIGNATURE_CONTRACT_ADDRESS`。

日志写入 `$runtime_dir/runtime-logs/<timestamp>/`，状态写入 `$runtime_dir/runtime-state/<timestamp>/`。默认配置写入 `$runtime_dir/runtime-state/<timestamp>/runtime-config/`，并通过 `GSTBK_RUNTIME_CONFIG_DIR` 传给 Proxy、Node 和 User；只有显式传入 `--legacy-fixture-configs` 时，才会写 legacy fixture 配置。`--keep-rendered-configs` 仅用于 legacy fixture 调试模式。

`manifest.json` 使用 `gstbk.e2e.manifest.v2` schema（结构版本），记录真实命令、起止时间、耗时、成功/失败状态、端口、合约地址、区块高度、日志路径、`config.runtime_config_dir`、角色日志 SHA-256（安全哈希算法 256 位）和身份密文 SHA-256，可用于复核本轮运行。

默认情况下，在 Git worktree（工作树）中跑完后不应留下配置改动。兼容旧流程时可加 `--legacy-fixture-configs`，脚本会在启动前备份被改写的 legacy fixture 配置，并在退出时恢复；调试时再叠加 `--keep-rendered-configs` 保留生成结果。

## 多角色启动顺序

`run-proxy.sh`、`run-node.sh` 和 `run-user.sh` 默认调用正式 bin（二进制入口）：

- `gstbk-proxy`：复用已跑通的 Proxy（代理）角色流程。
- `gstbk-node <1|2|3|4>`：按 Node（管理员节点）编号启动角色流程。
- `gstbk-user <1|2|3|4|5|6>`：按 User（用户）编号启动角色流程。

这些入口通过 `cargo run`（Cargo 运行命令）启动，不再默认依赖 `cargo test` 长运行测试入口。旧测试入口仍保留用于兼容和调试；如需显式回退，可设置：

```bash
export GSTBK_ROLE_ENTRYPOINT_MODE=test
```

未设置时等价于 `GSTBK_ROLE_ENTRYPOINT_MODE=bin`。

建议在不同终端启动，或由外部编排脚本按以下顺序后台启动：

```bash
bash scripts/run-local/run-proxy.sh

bash scripts/run-local/run-node.sh 1
bash scripts/run-local/run-node.sh 2
bash scripts/run-local/run-node.sh 3
bash scripts/run-local/run-node.sh 4

bash scripts/run-local/run-user.sh 1
bash scripts/run-local/run-user.sh 2
```

启动脚本支持通过环境变量覆盖配置路径：

- `GSTBK_RUNTIME_CONFIG_DIR`：统一 runtime 配置根目录。
- `GSTBK_PROXY_CONFIG_PATH`、`GSTBK_NODE_CONFIG_PATH`、`GSTBK_USER_CONFIG_PATH`：单角色配置文件路径，优先级高于统一目录。

`run-node.sh` 会在启动前创建 Node 运行态目录，默认是 legacy `crates/intergration_test/src/node/nodeN/info/`，设置 `GSTBK_RUNTIME_STATE_DIR` 后会改为 `$GSTBK_RUNTIME_STATE_DIR/node/nodeN/info/`，也可用 `GSTBK_NODE_INFO_DIR` 覆盖。`run-user.sh` 同理支持 `$GSTBK_RUNTIME_STATE_DIR/user/userN/info/` 和 `GSTBK_USER_INFO_DIR`，并在设置 `GSTBK_PERSONAL_INFO_PAYLOAD_PATH` 时把该文件复制为 `personal_info.json`，供签名后写入 `PersonalInfo` 合约。

## FISCO BCOS 联接

如需接入 FISCO BCOS（金融区块链合作联盟开源区块链底层平台），先启动链节点并准备 Java SDK（Software Development Kit，软件开发工具包）配置：

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
```

`FISCO_CONSOLE_DIR` 让 Gradle（构建工具）使用 console 自带的 `lib/*.jar`，适合 VM（Virtual Machine，虚拟机）外网或 DNS（Domain Name System，域名系统）不稳定时离线构建。

链端快速检查：

```bash
cd chain-apps/fisco-bcos-java-sdk
./info_run.sh blockNumber
./info_run.sh select <user>
./signature_run.sh select <user>
```

真实 `conf/config.toml`、证书、账户和私钥只保存在本地或 VM，不提交到仓库。
