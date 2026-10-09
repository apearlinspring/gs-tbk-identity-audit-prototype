# 配置与密钥管理

运行前需要准备链节点配置、SDK 证书、账户和 CL 密钥。本文说明这些文件的保存位置、Linux 权限以及检查方法。仓库提供配置模板和合成身份样例，实际运行文件在本地生成。

## 文件位置

配置模板为 `.env.example` 和 `conf/config.toml.example`。身份样例为 `examples/id-info/user1.json`、`user2.json`。

以下生成文件留在运行环境中，受 `.gitignore` 排除：

- `chain-apps/fisco-bcos-java-sdk/conf/config.toml` 和其他真实本地 `conf/*.toml`。
- `chain-apps/fisco-bcos-java-sdk/conf/sdk/` 下的真实 SDK 证书和私钥。
- `chain-apps/fisco-bcos-java-sdk/conf/accounts/` 下的真实链账户材料。
- wallet、wallets、keystore、keystores 目录及其内容。
- `.pem`、`.key`、`.crt`、`.p12`、`.pfx`、`.jks`、`.keystore` 等证书、私钥和密钥库文件。
- `private_key*`、`secret*`、`cl_keypair.json`、`wallet.json`、`account.json`、`accounts.json` 等生成密钥或账户文件。
- `runtime-state/`、`runtime-logs/`、`logs/`、`state/` 等运行状态与日志目录。
- `.env`、`.env.*`、`.env.fisco.generated` 和 `.env.fisco.generated.*`，但 `.env.example` 与 `.env.*.example` 可以入库。

真实身份输入和业务记录保存在运行环境，公开样例使用合成数据。

## 推荐权限

Linux 环境推荐以下权限；Windows 可用文件 ACL 限制访问。

| 材料 | 建议权限 | 说明 |
| --- | --- | --- |
| `conf/config.toml` | `600` 或 `640` | 运行用户可读；需要共享配置时可给同组只读。 |
| `conf/sdk/` | `700` 或 `750` | 包含 `sdk.key` 等证书材料。 |
| `conf/accounts/` | `700` | 链账户材料只给当前运行用户访问。 |
| wallet / keystore 目录 | `700` | 保存签名账户或私钥入口。 |
| 私钥、账户、keystore 文件 | `600` | 仅运行用户可读写。 |
| 运行日志 | `700` 目录、`600` 文件 | 日志可能包含链上返回、合约地址、身份密文哈希或错误上下文。 |
| 运行状态 | `700` 目录、`600` 文件 | 可能包含 CL 密钥、身份密文和协议中间状态。 |

`scripts/fisco/doctor.sh` 会对常见敏感路径做权限提示。默认模式下权限过宽会输出 warning；设置 `FISCO_DOCTOR_STRICT_SECRETS=1` 或使用 `--strict-secrets` 时，权限过宽会作为失败处理。

## 配置生成与权限检查

使用脚本准备 FISCO BCOS SDK 配置。`prepare-sdk-conf.sh` 会将 `conf/sdk` 和 `conf/accounts` 目录设置为 `700`，并将复制的 SDK 文件和 `conf/config.toml` 设置为 `600`：

```bash
bash scripts/fisco/prepare-sdk-conf.sh \
  --node-sdk-dir /home/gstbk/fisco/nodes/127.0.0.1/sdk \
  --app-dir "$PWD/chain-apps/fisco-bcos-java-sdk" \
  --group group0 \
  --peers 127.0.0.1:20200,127.0.0.1:20201 \
  --force
```

如果这些目录已经存在，先在仓库根目录设置权限，再运行严格检查：

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

如果运行账户需要通过共享用户组读取非私钥文件，可以把目录设为 `750`、普通配置文件设为 `640`；私钥、账户和 keystore 文件仍建议保持 `600`。

## 链上记录

`PersonalInfo` 保存身份字段密文、证明、承诺及业务上下文 JSON。`Signature` 保存签名 JSON，其中含用户编号和名称等元数据。两类记录都可以通过交易哈希、区块高度和历史查询追溯。

加密身份证号不等于整条记录匿名。部署时应根据业务需要设置元数据，CL 私钥、成员私钥和链账户私钥留在运行环境。

## 身份样例

本地复现使用虚构姓名、测试证件号和演示业务字段，例如 `测试用户一`、`测试用户二`。新增样例按现有 JSON 结构填写合成数据。

## 检查生成文件

运行后执行：

```bash
git status --short --branch
git check-ignore -v \
  .env.fisco.generated \
  chain-apps/fisco-bcos-java-sdk/conf/config.toml \
  chain-apps/fisco-bcos-java-sdk/conf/sdk/ \
  chain-apps/fisco-bcos-java-sdk/conf/accounts/
bash scripts/fisco/doctor.sh --allow-missing-contract-addresses
```

若生成配置、密钥或日志出现在 `git status` 中，检查输出路径和忽略规则，避免将运行文件加入提交。
