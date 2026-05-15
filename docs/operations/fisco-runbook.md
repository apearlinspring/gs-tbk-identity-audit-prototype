# FISCO BCOS 运维自动化 Runbook

本 Runbook（运行手册）面向 VM（Virtual Machine，虚拟机）`gstbk-vm` / `192.168.1.24` 上的 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）v3.6.0 环境。目标是从健康检查、Java SDK（Software Development Kit，软件开发工具包）配置准备、合约部署/复用，到 Rust（系统级编程语言）E2E（End-to-End，端到端）复现，都使用可诊断、可记录的脚本完成。

除非已经确认没有其他任务在跑，不要重建链、清空链数据或停止节点。真实证书、私钥、账户文件、wallet（钱包）材料、keystore（密钥库）文件和 `conf/config.toml` 禁止提交。

## 环境约定

| 字段 | 值 |
| --- | --- |
| Host（主机） | `gstbk-vm` |
| IP（Internet Protocol，互联网协议地址） | `192.168.1.24` |
| User（用户） | `gstbk` |
| OS（Operating System，操作系统） | Ubuntu 22.04.4 LTS |
| FISCO BCOS | v3.6.0 |
| 节点目录 | `/home/gstbk/fisco/nodes/127.0.0.1` |
| console（控制台）目录 | `/home/gstbk/fisco/console` |
| SDK 证书来源 | `/home/gstbk/fisco/nodes/127.0.0.1/sdk` |
| group（组） | `group0` |

推荐在 VM 上的 Git worktree（工作树）根目录执行以下命令。

## 0. 推荐一键入口

`bootstrap-vm-smoke.sh` 是 bootstrap（引导）入口，默认面向当前 VM 基线：准备 Java SDK 配置、运行 doctor（健康检查）、复用合约、校验 `.env.fisco.generated`，再输出部署摘要。默认 `--smoke none` 不启动 Rust 角色、不写新业务数据，只做非破坏性 doctor/reuse 路径：

```bash
bash scripts/fisco/bootstrap-vm-smoke.sh \
  --contract-mode reuse \
  --smoke none
```

成功摘要会包含：

- FISCO BCOS 链版本。
- group（组）。
- FISCO 节点端口和 Rust 角色端口。
- `PersonalInfo` 与 `Signature` 合约地址。
- 当前 `blockNumber`。
- 生成环境文件路径。
- 本轮实际运行命令。

如需继续跑 Rust E2E（End-to-End，端到端）smoke（冒烟验证），使用：

```bash
bash scripts/fisco/bootstrap-vm-smoke.sh \
  --contract-mode reuse \
  --smoke e2e
```

如需跑 service（服务）supervisor（管理器）smoke，使用：

```bash
bash scripts/fisco/bootstrap-vm-smoke.sh \
  --contract-mode reuse \
  --smoke service
```

只有确认需要写入新合约时，才使用 `--contract-mode deploy`。该入口不会重建链、不会清空链数据、不会停止 FISCO BCOS 节点。

## 1. 进入工作目录

```bash
ssh gstbk@192.168.1.24
cd /path/to/gs_tbk_wt_chain_ops
git status --short --branch
```

确认当前分支是 `feat/deployment-automation-polish`，并确认没有未预期改动。

## 2. 准备 Java SDK 配置

先查看将复制哪些敏感文件：

```bash
bash scripts/fisco/prepare-sdk-conf.sh \
  --node-sdk-dir /home/gstbk/fisco/nodes/127.0.0.1/sdk \
  --app-dir "$PWD/chain-apps/fisco-bcos-java-sdk" \
  --group group0 \
  --peers 127.0.0.1:20200,127.0.0.1:20201 \
  --dry-run
```

确认路径无误后生成真实配置：

```bash
bash scripts/fisco/prepare-sdk-conf.sh \
  --node-sdk-dir /home/gstbk/fisco/nodes/127.0.0.1/sdk \
  --app-dir "$PWD/chain-apps/fisco-bcos-java-sdk" \
  --group group0 \
  --peers 127.0.0.1:20200,127.0.0.1:20201 \
  --force
```

生成内容默认位于：

- `chain-apps/fisco-bcos-java-sdk/conf/config.toml`
- `chain-apps/fisco-bcos-java-sdk/conf/sdk/`
- `chain-apps/fisco-bcos-java-sdk/conf/accounts/`

这些路径被 `.gitignore` 排除，不能手工 `git add -f`。

## 3. 导出基础环境变量

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
```

如果 VM 上没有 `/tmp/gradle-8.10.2/bin/gradle`，可先确认 `chain-apps/fisco-bcos-java-sdk/gradlew` 是否可用。`FISCO_CONSOLE_DIR` 会让 Gradle（构建工具）优先复用 console 自带的 FISCO BCOS jar（Java 归档文件），减少外网依赖。

## 4. 运行健康检查

已有合约地址时：

```bash
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x6546c3571f17858ea45575e7c6457dad03e53dbb
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0xcceef68c9b4811b32c75df284a1396c7c5509561

bash scripts/fisco/doctor.sh
```

还没有合约地址时，先做部署前检查：

```bash
bash scripts/fisco/doctor.sh --allow-missing-contract-addresses
```

`doctor.sh` 会检查 Java、Gradle、console、SDK 配置、证书目录、节点进程、端口、group、`blockNumber` 和两个合约地址变量。读取到 `blockNumber` 说明 Java SDK 已能连通当前 group。

## 5. 部署或复用合约

优先复用当前 E2E 基线合约，避免不必要链上写入：

```bash
bash scripts/fisco/deploy-contracts.sh \
  --mode reuse \
  --personal-info-address 0x6546c3571f17858ea45575e7c6457dad03e53dbb \
  --signature-address 0xcceef68c9b4811b32c75df284a1396c7c5509561
```

脚本会调用现有 `info_run.sh` 和 `signature_run.sh` 做 `select __gstbk_probe__` 探测，并生成：

```text
.env.fisco.generated
```

如确实需要部署新合约：

```bash
bash scripts/fisco/deploy-contracts.sh --mode deploy
```

部署模式会调用 `info_run.sh deploy` 和 `signature_run.sh deploy`，记录新合约地址和部署后的 `blockNumber`。当前 Java SDK 部署命令不打印交易哈希；合约 `register` 才会输出 `transactionHash`。

使用生成环境：

```bash
set -a
. ./.env.fisco.generated
set +a
```

生成文件现在会被脚本自校验。若缺少 `FISCO_CONFIG`、`FISCO_GROUP`、`GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS`、`GSTBK_SIGNATURE_CONTRACT_ADDRESS`，或 `FISCO_CONFIG` 指向的文件不存在，会提前失败，不再等到 E2E 或 service smoke 阶段才暴露。

再次运行健康检查：

```bash
bash scripts/fisco/doctor.sh
```

## 6. 运行 Rust E2E

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

manifest（运行清单）会记录命令、合约地址、区块高度、链上写入结果、角色日志哈希和配置恢复状态。

## 7. 复核工作树和敏感文件

```bash
git status --short --branch
git check-ignore -v .env.fisco.generated chain-apps/fisco-bcos-java-sdk/conf/config.toml
```

预期 `git status` 不出现真实配置、证书、账户或运行日志。若这些文件意外出现在待提交列表，先停止提交并检查 `.gitignore` 与执行路径。

## 常见故障

| 现象 | 处理 |
| --- | --- |
| `doctor.sh` 报 `FISCO SDK config not found` | 先运行 `prepare-sdk-conf.sh --force`，或设置正确的 `FISCO_CONFIG`。 |
| `doctor.sh` 报证书缺失 | 确认 `/home/gstbk/fisco/nodes/127.0.0.1/sdk` 存在，再重跑配置准备脚本。 |
| `blockNumber` 失败 | 检查节点进程、`20200/20201` 端口、`FISCO_GROUP` 和 `FISCO_CONFIG`。 |
| Gradle 下载依赖失败 | 设置 `FISCO_CONSOLE_DIR=/home/gstbk/fisco/console`，必要时设置 `GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle`。 |
| 合约地址缺失或全零 | 使用 `deploy-contracts.sh --mode reuse` 复用基线地址，或明确执行 `--mode deploy`。 |
| E2E 端口被占用 | 不直接杀进程；先确认是否有其他任务在跑，再决定是否换端口或等待。 |
| `bootstrap-vm-smoke.sh` 校验 `.env.fisco.generated` 失败 | 检查 `deploy-contracts.sh` 是否成功写入 env 文件，确认 `FISCO_CONFIG`、`FISCO_GROUP` 和两个合约地址都存在且不是全零地址。 |
