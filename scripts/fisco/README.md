# FISCO BCOS 运维脚本

本目录把 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）链环境检查、Java SDK（Software Development Kit，软件开发工具包）配置准备和合约部署/复用整理为可重复脚本。脚本默认只复用已有链，不启动、停止或重建节点。

## 脚本列表

| 脚本 | 用途 |
| --- | --- |
| `bootstrap-vm-smoke.sh` | VM（Virtual Machine，虚拟机）一键入口，串联 SDK 配置准备、doctor（健康检查）、合约复用/部署、生成环境校验和可选 E2E（End-to-End，端到端）/service smoke（服务冒烟验证）。 |
| `doctor.sh` | 检查 Java（编程语言运行环境）、Gradle（构建工具）、console（控制台）、SDK 配置、证书目录、节点进程、端口、group（组）、`blockNumber`、合约地址变量、敏感路径 ignore（忽略）覆盖和权限。 |
| `prepare-sdk-conf.sh` | 从 FISCO 节点 `sdk/` 目录复制证书到 Java SDK 的被忽略目录，并生成真实 `conf/config.toml`。 |
| `deploy-contracts.sh` | 通过现有 `info_run.sh` / `signature_run.sh` 部署或复用 `PersonalInfo` 与 `Signature`，并写出被忽略的 `.env.fisco.generated`。 |

真实 `conf/config.toml`、证书、私钥、账户文件、wallet（钱包）、keystore（密钥库）和 `.env.fisco.generated` 都应留在本地或 VM（Virtual Machine，虚拟机）上，不提交 Git（分布式版本控制系统）。完整边界见 `docs/operations/secrets-and-config.md`。

## 一键 VM smoke

非破坏性复用路径只探测当前基线合约，不重建链、不清空链数据：

```bash
bash scripts/fisco/bootstrap-vm-smoke.sh \
  --contract-mode reuse \
  --smoke none
```

如需在同一入口继续跑 Rust E2E：

```bash
bash scripts/fisco/bootstrap-vm-smoke.sh \
  --contract-mode reuse \
  --smoke e2e
```

也可以选择本地服务管理 smoke：

```bash
bash scripts/fisco/bootstrap-vm-smoke.sh \
  --contract-mode reuse \
  --smoke service
```

脚本默认使用 VM 当前基线地址；如果要复用其他合约，显式传入 `--personal-info-address` 和 `--signature-address`。部署新合约时使用 `--contract-mode deploy`。

## 准备 SDK 配置

在 VM 上从仓库根目录执行：

```bash
bash scripts/fisco/prepare-sdk-conf.sh \
  --node-sdk-dir /home/gstbk/fisco/nodes/127.0.0.1/sdk \
  --app-dir "$PWD/chain-apps/fisco-bcos-java-sdk" \
  --group group0 \
  --peers 127.0.0.1:20200,127.0.0.1:20201 \
  --force
```

先查看将复制哪些敏感文件：

```bash
bash scripts/fisco/prepare-sdk-conf.sh --dry-run
```

默认输出：

- `chain-apps/fisco-bcos-java-sdk/conf/config.toml`
- `chain-apps/fisco-bcos-java-sdk/conf/sdk/*`
- `chain-apps/fisco-bcos-java-sdk/conf/accounts/`

这些路径已被 `.gitignore` 排除。
脚本会把 `conf/sdk` 和 `conf/accounts` 目录设置为 `700`，并把复制的证书、私钥和 `conf/config.toml` 设置为 `600`，以便直接通过 strict（严格）敏感配置检查。

## 健康检查

已有合约地址时：

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x6546c3571f17858ea45575e7c6457dad03e53dbb
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0xcceef68c9b4811b32c75df284a1396c7c5509561

bash scripts/fisco/doctor.sh
```

还未部署合约时，可先允许合约地址缺失：

```bash
bash scripts/fisco/doctor.sh --allow-missing-contract-addresses
```

脚本出现 `[FAIL]` 时返回非 0；`[WARN]` 表示需要关注但不一定阻塞当前阶段。

如需把敏感文件权限过宽视为阻塞问题，可启用 strict（严格）模式：

```bash
FISCO_DOCTOR_STRICT_SECRETS=1 bash scripts/fisco/doctor.sh --allow-missing-contract-addresses
# 或
bash scripts/fisco/doctor.sh --strict-secrets --allow-missing-contract-addresses
```

## 部署或复用合约

复用已知合约地址并生成本地环境文件：

```bash
bash scripts/fisco/deploy-contracts.sh \
  --mode reuse \
  --personal-info-address 0x6546c3571f17858ea45575e7c6457dad03e53dbb \
  --signature-address 0xcceef68c9b4811b32c75df284a1396c7c5509561
```

部署两个新合约：

```bash
bash scripts/fisco/deploy-contracts.sh --mode deploy
```

`auto` 模式会复用已设置的合法地址，只部署缺失的合约：

```bash
bash scripts/fisco/deploy-contracts.sh --mode auto
```

脚本输出 `.env.fisco.generated`，可用于后续 E2E（End-to-End，端到端）运行：

```bash
set -a
. ./.env.fisco.generated
set +a
```

当前 Java SDK 的 `deploy` 命令会输出合约地址和部署后的 `blockNumber`；`register` 命令才输出交易哈希。若只复用合约，脚本会执行 `select __gstbk_probe__` 探测并记录复用判断。

## 质量检查

本目录脚本应至少通过语法检查：

```bash
bash -n scripts/fisco/*.sh
```
