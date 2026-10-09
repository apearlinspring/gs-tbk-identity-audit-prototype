# FISCO BCOS 运行手册

按以下步骤准备 Java SDK 配置、检查链节点、部署或复用合约，再运行 Rust E2E。命令从仓库根目录执行。

脚本使用已运行的链节点。运行配置和证书的权限要求见[配置与密钥管理](secrets-and-config.md)。

## 环境约定

以下路径按目标环境替换：

| 字段 | 示例 |
| --- | --- |
| FISCO BCOS 版本 | `v3.6.0` |
| group | `group0` |
| 节点 SDK 证书目录 | `/path/to/fisco/nodes/127.0.0.1/sdk` |
| console 目录 | `/path/to/fisco/console` |
| Java / Gradle | OpenJDK 11 / Gradle 8.x |

## 0. 初始化入口

`bootstrap-vm-smoke.sh` 串联配置准备、环境检查和合约部署或复用，可选运行 E2E 或服务管理演示。

```bash
bash scripts/fisco/bootstrap-vm-smoke.sh \
  --contract-mode reuse \
  --smoke none
```

如需继续跑 Rust E2E：

```bash
bash scripts/fisco/bootstrap-vm-smoke.sh \
  --contract-mode reuse \
  --smoke e2e
```

`--contract-mode deploy` 会部署新合约；`reuse` 使用已有地址。

## 1. 准备 Java SDK 配置

先查看配置来源和输出路径：

```bash
bash scripts/fisco/prepare-sdk-conf.sh \
  --node-sdk-dir /path/to/fisco/nodes/127.0.0.1/sdk \
  --app-dir "$PWD/chain-apps/fisco-bcos-java-sdk" \
  --group group0 \
  --peers 127.0.0.1:20200,127.0.0.1:20201 \
  --dry-run
```

确认路径后生成配置：

```bash
bash scripts/fisco/prepare-sdk-conf.sh \
  --node-sdk-dir /path/to/fisco/nodes/127.0.0.1/sdk \
  --app-dir "$PWD/chain-apps/fisco-bcos-java-sdk" \
  --group group0 \
  --peers 127.0.0.1:20200,127.0.0.1:20201 \
  --force
```

生成内容默认位于：

- `chain-apps/fisco-bcos-java-sdk/conf/config.toml`
- `chain-apps/fisco-bcos-java-sdk/conf/sdk/`
- `chain-apps/fisco-bcos-java-sdk/conf/accounts/`

这些生成路径已被 `.gitignore` 排除。

## 2. 导出基础环境变量

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/path/to/fisco/console
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
```

如果目标环境已经安装 Gradle，也可设置：

```bash
export GRADLE_BIN=/path/to/gradle/bin/gradle
```

`FISCO_CONSOLE_DIR` 会让 Gradle 优先复用 console 自带的 FISCO BCOS jar，减少外网依赖。

## 3. 运行健康检查

已有合约地址时：

```bash
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...

bash scripts/fisco/doctor.sh
```

还没有合约地址时，先做部署前检查：

```bash
bash scripts/fisco/doctor.sh --allow-missing-contract-addresses
```

`doctor.sh` 会检查 Java、Gradle、console、SDK 配置、证书目录、节点进程、端口、group、`blockNumber` 和两个合约地址变量。

## 4. 部署或复用合约

复用已部署合约：

```bash
bash scripts/fisco/deploy-contracts.sh \
  --mode reuse \
  --personal-info-address "$GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" \
  --signature-address "$GSTBK_SIGNATURE_CONTRACT_ADDRESS"
```

部署新合约：

```bash
bash scripts/fisco/deploy-contracts.sh --mode deploy
```

脚本生成 `.env.fisco.generated`，检查并加载：

```bash
git check-ignore -v .env.fisco.generated
set -a
. ./.env.fisco.generated
set +a
```

## 5. 运行 Rust E2E

```bash
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"

bash scripts/run-local/run-e2e.sh \
  --users 2 \
  --nodes 4 \
  --runtime-dir /tmp/gstbk-e2e-ops \
  --reuse-chain \
  --contract-addresses-from-env \
  --timeout-seconds 300
```

运行产物位于：

- `/tmp/gstbk-e2e-ops/runtime-logs/<timestamp>/manifest.json`
- `/tmp/gstbk-e2e-ops/runtime-state/<timestamp>/`

manifest 会记录命令、合约地址、区块高度、链上写入结果、角色日志哈希和配置恢复状态。

## 6. 检查运行产物

```bash
git status --short --branch
git check-ignore -v .env.fisco.generated chain-apps/fisco-bcos-java-sdk/conf/config.toml
```

确认生成配置和日志已被忽略，工作树没有配置残留改动。

## 常见故障

| 现象 | 处理 |
| --- | --- |
| `doctor.sh` 报 `FISCO SDK config not found` | 先运行 `prepare-sdk-conf.sh --force`，或设置正确的 `FISCO_CONFIG`。 |
| `doctor.sh` 报证书缺失 | 确认节点 SDK 证书目录存在，再重跑配置准备脚本。 |
| `blockNumber` 失败 | 检查节点进程、channel 端口、`FISCO_GROUP` 和 `FISCO_CONFIG`。 |
| Gradle 下载依赖失败 | 设置 `FISCO_CONSOLE_DIR`，必要时设置 `GRADLE_BIN` 指向本地 Gradle。 |
| 合约地址缺失或全零 | 使用 `deploy-contracts.sh --mode reuse` 复用已有地址，或明确执行 `--mode deploy`。 |
| E2E 端口被占用 | 先确认是否有其他任务在跑，再决定是否换端口或等待。 |
