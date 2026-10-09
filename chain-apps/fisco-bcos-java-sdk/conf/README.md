# 配置说明

Java SDK 从本目录加载链端配置、SDK 证书和账户。生成文件已由 `.gitignore` 排除。

- `config.toml.example`：示例配置，仅用于说明字段形态。
- `config.toml`：本机运行配置。
- `sdk/`：SDK 证书目录，来自节点的 `sdk` 目录。
- `accounts/`：账户文件目录，例如 PEM 私钥文件或 keystore 文件。
- `contract-addresses.env`：可选的本地合约地址文件。

准备配置：

```bash
cd chain-apps/fisco-bcos-java-sdk
cp conf/config.toml.example conf/config.toml
mkdir -p conf/sdk conf/accounts
cp ~/fisco/nodes/127.0.0.1/sdk/* conf/sdk/
```

`config.toml` 中常用字段：

- `cryptoMaterial.certPath`：证书目录，默认示例为 `conf/sdk`。
- `network.peers`：节点 RPC 地址，例如 `127.0.0.1:20200`。
- `account.keyStoreDir`：账户文件目录。未指定 `accountFilePath` 时，SDK 会按配置加载或生成本地账户材料。

通过环境变量指定合约地址：

```bash
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...
```

文件权限和保存方式见[配置与密钥管理](../../../docs/operations/secrets-and-config.md)。
