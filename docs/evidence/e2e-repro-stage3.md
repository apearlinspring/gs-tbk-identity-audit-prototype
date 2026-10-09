# 阶段 3 E2E 复现记录

本文记录阶段 3 的 E2E 复现步骤：Rust 协议角色通过 Java SDK 将签名和身份密文写入 FISCO BCOS，再执行查询、Verify 和 Open。

## 目标

验证流程：

```text
1 Proxy
+ 4 Node
+ 2 User
-> KeyGen
-> Join
-> Revoke
-> Sign
-> Signature / PersonalInfo register
-> Node select
-> Verify
-> Open
```

## 环境准备

```bash
sudo apt-get update
sudo apt-get install -y build-essential pkg-config libgmp-dev pari-gp libpari-dev bison clang libclang-dev
```

准备 Java SDK 配置：

```bash
cd chain-apps/fisco-bcos-java-sdk
cp conf/config.toml.example conf/config.toml
mkdir -p conf/sdk conf/accounts
cp /path/to/fisco/nodes/127.0.0.1/sdk/* conf/sdk/
```

配置和证书的权限要求见[配置与密钥管理](../operations/secrets-and-config.md)。

## 构建检查

```bash
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"
cargo check --workspace
```

这一阶段仍有历史格式差异，未将全工作区格式检查作为验收结果。

## 链端配置

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/path/to/fisco/console
export GRADLE_BIN=/path/to/gradle/bin/gradle
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
```

部署或复用合约：

```bash
bash scripts/fisco/deploy-contracts.sh --mode deploy
```

或复用已有地址：

```bash
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...

bash scripts/fisco/deploy-contracts.sh \
  --mode reuse \
  --personal-info-address "$GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" \
  --signature-address "$GSTBK_SIGNATURE_CONTRACT_ADDRESS"
```

## 身份字段

```bash
export GSTBK_RUNTIME_DIR=/tmp/gstbk-e2e-smoke/runtime-state
export GSTBK_CL_KEYPAIR_PATH="$GSTBK_RUNTIME_DIR/cl_keypair.json"

bash scripts/run-local/run-id-info.sh keygen
bash scripts/run-local/run-id-info.sh enc \
  --input examples/id-info/user1.json \
  --output "$GSTBK_RUNTIME_DIR/user1-block-personal-info.json"
bash scripts/run-local/run-id-info.sh verify \
  --input "$GSTBK_RUNTIME_DIR/user1-block-personal-info.json"
```

## 一键 E2E

```bash
bash scripts/run-local/run-e2e.sh \
  --users 2 \
  --nodes 4 \
  --runtime-dir /tmp/gstbk-e2e-smoke \
  --reuse-chain \
  --contract-addresses-from-env \
  --timeout-seconds 300
```

成功后应得到：

- `runtime-logs/<timestamp>/manifest.json`
- Proxy 与 4 个 Node 完成 KeyGen。
- 2 个 User 完成 Join 和 Sign。
- `Signature` 与 `PersonalInfo` register 返回交易哈希和区块号。
- Node 查询 `Signature` 返回 `exists true`。
- Verify/Open 阶段完成。

## 失败场景

`run-e2e.sh` 已覆盖以下前置失败：

| 场景 | 预期 |
| --- | --- |
| 未传 `--reuse-chain` | 提前失败，不隐式启动或重建 FISCO BCOS。 |
| 缺少合约地址 | 使用 `--contract-addresses-from-env` 时提前失败。 |
| 端口占用 | 启动角色前失败并指出端口号。 |
| 缺少 User 输入样例 | 渲染配置和启动角色前失败。 |

## 运行后检查

```bash
git status --short --branch
git check-ignore -v chain-apps/fisco-bcos-java-sdk/conf/config.toml runtime-logs runtime-state
```

确认运行目录被忽略，工作树没有配置残留改动。
