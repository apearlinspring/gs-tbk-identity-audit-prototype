# 敏感材料与配置边界

本文说明 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）、Java SDK（Software Development Kit，软件开发工具包）和 Rust（系统级编程语言）运行流程中的配置边界。目标是让仓库只保存可复现工程材料，不保存真实证书、账户、wallet（钱包）、keystore（密钥库）、私钥、运行日志或明文身份字段。

## 入库边界

可以入库的材料：

- `.example` 模板，例如 `.env.example`、`conf/config.toml.example`。
- `README`、Runbook（运行手册）、架构说明、证据索引和不含真实秘密的操作文档。
- 无密钥脚本，例如 `scripts/fisco/*.sh`、`scripts/run-local/*.sh`。
- 脱敏后的示例输入，例如 `examples/id-info/user1.json` 和 `examples/id-info/user2.json`。
- 不含真实节点证书、账户或私钥的合约源码、Java SDK wrapper（包装类）和 Rust 业务代码。

禁止入库的材料：

- `chain-apps/fisco-bcos-java-sdk/conf/config.toml` 和其他真实本地 `conf/*.toml`。
- `chain-apps/fisco-bcos-java-sdk/conf/sdk/` 下的真实 SDK 证书和私钥。
- `chain-apps/fisco-bcos-java-sdk/conf/accounts/` 下的真实链账户材料。
- wallet、wallets、keystore、keystores 目录及其内容。
- `.pem`、`.key`、`.crt`、`.p12`、`.pfx`、`.jks`、`.keystore` 等证书、私钥和密钥库文件。
- `private_key*`、`secret*`、`cl_keypair.json`、`wallet.json`、`account.json`、`accounts.json` 等生成密钥或账户文件。
- `runtime-state/`、`runtime-logs/`、`logs/`、`state/` 等运行状态与日志目录。
- `.env`、`.env.*`、`.env.fisco.generated` 和 `.env.fisco.generated.*`，但 `.env.example` 与 `.env.*.example` 可以入库。
- 真实身份字段样例、真实身份证号、真实姓名、真实机构业务流水和未脱敏原始输入。

## 推荐权限

以下权限建议面向 Linux（操作系统内核）或 VM（Virtual Machine，虚拟机）环境。Windows（微软操作系统）本地编辑时无法完全等价表达 POSIX（Portable Operating System Interface，可移植操作系统接口）权限，至少要保证文件不被同步或提交到 Git（分布式版本控制系统）。

| 材料 | 建议权限 | 说明 |
| --- | --- | --- |
| `conf/config.toml` | `600` 或 `640` | 配置中包含证书路径、账户路径和链端连接信息；可给同组只读，但不应对其他用户可读。 |
| `conf/sdk/` | `700` 或 `750` | 目录中通常包含 `sdk.key`，不应对其他用户开放。 |
| `conf/accounts/` | `700` | 链账户材料只给当前运行用户访问。 |
| wallet / keystore 目录 | `700` | wallet 和 keystore 通常直接代表签名身份或私钥入口。 |
| 私钥、账户、keystore 文件 | `600` | 不建议组读，更不应 world-readable（所有用户可读）。 |
| runtime logs（运行时日志） | `700` 目录、`600` 文件 | 日志可能包含链上返回、合约地址、身份密文哈希或错误上下文。 |
| runtime state（运行时状态） | `700` 目录、`600` 文件 | 可能包含 CL（Castagnos-Laguillaumie，同态加密方案）密钥、身份密文和协议中间状态。 |

`scripts/fisco/doctor.sh` 会对常见敏感路径做权限提示。默认模式下权限过宽会输出 warning（警告）；设置 `FISCO_DOCTOR_STRICT_SECRETS=1` 或使用 `--strict-secrets` 时，权限过宽会作为失败处理。

## VM strict secrets 复核

在 VM（Virtual Machine，虚拟机）或 Linux 环境准备真实 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）SDK 配置时，优先使用脚本生成本地 ignored（已忽略）配置。`prepare-sdk-conf.sh` 会将 `conf/sdk` 和 `conf/accounts` 目录设置为 `700`，并将复制的 SDK（Software Development Kit，软件开发工具包）文件和 `conf/config.toml` 设置为 `600`：

```bash
bash scripts/fisco/prepare-sdk-conf.sh \
  --node-sdk-dir /home/gstbk/fisco/nodes/127.0.0.1/sdk \
  --app-dir "$PWD/chain-apps/fisco-bcos-java-sdk" \
  --group group0 \
  --peers 127.0.0.1:20200,127.0.0.1:20201 \
  --force
```

如果这些目录已经存在，先在仓库根目录中收紧权限，再运行 strict doctor（严格健康检查）：

```bash
app="$PWD/chain-apps/fisco-bcos-java-sdk"

for dir in \
  "$app/conf/sdk" \
  "$app/conf/accounts" \
  "$app/conf/account" \
  "$app/conf/wallet" \
  "$app/conf/wallets" \
  "$app/conf/keystore" \
  "$app/conf/keystores"; do
  [ -d "$dir" ] && chmod 700 "$dir"
done

for dir in "$app/conf/sdk" "$app/conf/accounts" "$app/conf/wallet" "$app/conf/keystore"; do
  [ -d "$dir" ] && find "$dir" -type f -exec chmod 600 {} +
done

[ -f "$app/conf/config.toml" ] && chmod 600 "$app/conf/config.toml"

FISCO_DOCTOR_STRICT_SECRETS=1 bash scripts/fisco/doctor.sh
```

如果运行账户需要通过共享 group（组）读取非私钥文件，可以把目录设为 `750`、普通配置文件设为 `640`；私钥、账户和 keystore 文件仍建议保持 `600`。

## 链上审计边界

链上保存的是审计所需的密文和证明材料，不保存明文身份字段。

- `PersonalInfo` 合约保存身份密文、ZKP（Zero-Knowledge Proof，零知识证明）、commitment（承诺）和脱敏后的业务上下文 JSON（JavaScript Object Notation，数据交换格式）。
- `Signature` 合约保存用户签名 JSON，用于后续 Node（管理员节点）查询、Verify（验证）和 Open（揭示）。
- 明文姓名、明文身份证号、监管者 CL 私钥、用户私钥、链账户私钥、证书私钥不写入链上，也不写入仓库。
- 链上交易会留下交易哈希、区块高度、合约地址和事件/表记录，这些可作为审计证据，但不应反推出明文身份字段。
- 如果需要展示链上数据，应展示密文、证明、承诺、签名摘要、交易哈希和区块高度，不展示真实身份明文。

## 身份样例脱敏

样例身份字段只用于复现编码、加密、证明和链上写入流程，不应模拟真实自然人。

- 姓名使用 `测试用户一`、`测试用户二` 等虚构名称。
- 身份证号使用明显测试号段或占位号，不使用真实地区、真实出生日期和真实校验位组合。
- 机构、地点和行为字段保持演示语义即可，不记录真实业务流水、真实办件编号或真实个人轨迹。
- 从外部材料导入样例前，先删除真实姓名、证件号、手机号、地址、账户、证书和密钥字段。

## 操作检查清单

提交前建议执行：

```bash
git status --short --branch
git check-ignore -v \
  .env.fisco.generated \
  chain-apps/fisco-bcos-java-sdk/conf/config.toml \
  chain-apps/fisco-bcos-java-sdk/conf/sdk/ \
  chain-apps/fisco-bcos-java-sdk/conf/accounts/
bash scripts/fisco/doctor.sh --allow-missing-contract-addresses
```

如果 `git status` 中出现真实 `conf/config.toml`、证书、账户、wallet、keystore、runtime state 或运行日志，先停止提交并检查 `.gitignore` 与执行路径。不要用 `git add -f` 强行加入这些材料。
