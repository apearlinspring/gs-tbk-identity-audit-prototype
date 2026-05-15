# FISCO strict secrets VM 证据

本文记录 2026-05-12 在真实 VM（Virtual Machine，虚拟机）`gstbk-vm` 上对 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）敏感配置权限的严格检查。检查只记录命令、路径、权限和摘要；真实 `conf/config.toml`、SDK（Software Development Kit，软件开发工具包）证书、私钥、账户、wallet（钱包）和 keystore（密钥库）材料均未写入仓库。

## 结论

| 项目 | 结果 |
| --- | --- |
| VM | `gstbk-vm` / Ubuntu 22.04.4 LTS |
| 验证目录 | `/tmp/gstbk-strict-secrets-verify` |
| FISCO group（组） | `group0` |
| 合约地址 | 复用当前基线 `PersonalInfo` / `Signature` 地址 |
| strict doctor（严格健康检查） | 通过 |
| 剩余 warning（警告） | `0` |
| 真实秘密入库 | 未发生；真实材料只位于 VM 临时验证目录中的 ignored（已忽略）路径 |

## 同步与配置准备

本地将当前 HEAD（当前提交指针）打包后传到 VM：

```bash
git bundle create ../gs_tbk_wt_strict_secrets.bundle HEAD
scp ../gs_tbk_wt_strict_secrets.bundle gstbk-vm:/tmp/
```

进入 VM 的临时目录，并只在临时目录中复制真实 SDK 证书：

```bash
rm -rf /tmp/gstbk-strict-secrets-verify
git clone /tmp/gs_tbk_wt_strict_secrets.bundle /tmp/gstbk-strict-secrets-verify
cd /tmp/gstbk-strict-secrets-verify

GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle \
bash scripts/fisco/prepare-sdk-conf.sh \
  --node-sdk-dir /home/gstbk/fisco/nodes/127.0.0.1/sdk \
  --app-dir "$PWD/chain-apps/fisco-bcos-java-sdk" \
  --group group0 \
  --peers 127.0.0.1:20200,127.0.0.1:20201 \
  --force
```

`prepare-sdk-conf.sh` 本轮已调整为生成 `conf/sdk` 和 `conf/accounts` 后主动设置目录权限为 `700`，并继续用 `600` 写入复制的 SDK 文件和 `conf/config.toml`。

## 权限摘要

复核命令：

```bash
cd /tmp/gstbk-strict-secrets-verify
stat -c '%a %U:%G %n' \
  chain-apps/fisco-bcos-java-sdk/conf/config.toml \
  chain-apps/fisco-bcos-java-sdk/conf/sdk \
  chain-apps/fisco-bcos-java-sdk/conf/sdk/ca.crt \
  chain-apps/fisco-bcos-java-sdk/conf/sdk/sdk.crt \
  chain-apps/fisco-bcos-java-sdk/conf/sdk/sdk.key \
  chain-apps/fisco-bcos-java-sdk/conf/accounts
```

结果摘要：

```text
600 gstbk:gstbk chain-apps/fisco-bcos-java-sdk/conf/config.toml
700 gstbk:gstbk chain-apps/fisco-bcos-java-sdk/conf/sdk
600 gstbk:gstbk chain-apps/fisco-bcos-java-sdk/conf/sdk/ca.crt
600 gstbk:gstbk chain-apps/fisco-bcos-java-sdk/conf/sdk/sdk.crt
600 gstbk:gstbk chain-apps/fisco-bcos-java-sdk/conf/sdk/sdk.key
700 gstbk:gstbk chain-apps/fisco-bcos-java-sdk/conf/accounts
absent chain-apps/fisco-bcos-java-sdk/conf/wallet
absent chain-apps/fisco-bcos-java-sdk/conf/keystore
```

## strict 行为核对

`doctor.sh --strict-secrets` 或 `FISCO_DOCTOR_STRICT_SECRETS=1` 会把敏感路径 ignore（忽略）缺失、敏感目录权限过宽、敏感文件权限过宽从 warning 升级为 fail（失败）。本轮做了一个临时负向检查：仅在 `/tmp/gstbk-strict-secrets-verify` 中短暂把 `conf/sdk` 改为 `755`，确认 strict doctor 失败，然后立即恢复为 `700`。

负向检查摘要：

```text
negative_rc=1
[FAIL] Sensitive directory permissions are 755; recommend 700 or 750: /tmp/gstbk-strict-secrets-verify/chain-apps/fisco-bcos-java-sdk/conf/sdk
[FAIL] SDK certificate directory permissions are 755; recommend 700 or 750: /tmp/gstbk-strict-secrets-verify/chain-apps/fisco-bcos-java-sdk/conf/sdk
[SUMMARY] doctor failed: 2 failure(s), 0 warning(s).
```

## 最终 strict doctor

最终命令：

```bash
cd /tmp/gstbk-strict-secrets-verify
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x6546c3571f17858ea45575e7c6457dad03e53dbb
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0xcceef68c9b4811b32c75df284a1396c7c5509561

FISCO_DOCTOR_STRICT_SECRETS=1 bash scripts/fisco/doctor.sh
```

关键结果：

| 检查项 | 结果 |
| --- | --- |
| Git（分布式版本控制系统）ignore 覆盖 | `.env`、runtime、`conf/config.toml`、`conf/sdk/`、`conf/accounts/`、wallet、keystore 等敏感路径均覆盖 |
| `FISCO_CONFIG` | 存在，权限 `600` |
| `conf/sdk` | 存在，目录权限 `700` |
| `conf/sdk/sdk.key` | 存在，文件权限 `600` |
| `conf/accounts` | 存在，目录权限 `700` |
| wallet / wallets | 不存在，doctor 记录为 info（信息） |
| keystore / keystores | 不存在，doctor 记录为 info |
| Java（编程语言运行环境）/ Gradle（构建工具） | OpenJDK 11.0.30 / Gradle 8.10.2 可用 |
| FISCO 节点 | 4 个真实 `fisco-bcos` 进程 |
| 端口 | `20200`、`20201`、`30300`、`30301` 均监听 |
| Java SDK `blockNumber` | `50` |

最终输出摘要：

```text
[OK]   fisco-bcos process count: 4
[OK]   Port 20200 is listening.
[OK]   Port 20201 is listening.
[OK]   Port 30300 is listening.
[OK]   Port 30301 is listening.
[OK]   Java SDK blockNumber for group0: 50
[SUMMARY] doctor passed: 0 warning(s).
```

## 剩余风险

本轮没有剩余 strict doctor warning。仍需持续遵守的边界是：真实 `conf/config.toml`、SDK 证书、账户、wallet、keystore、私钥和运行日志只保留在 VM 或安全本地目录，不提交到仓库；如果后续引入共享 service（服务）账户，可将敏感目录放宽到 `750`、非私钥配置文件放宽到 `640`，但私钥和账户文件仍建议保持 `600`。
