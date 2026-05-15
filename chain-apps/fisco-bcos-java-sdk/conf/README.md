# 配置说明

本目录用于放置 FISCO BCOS Java SDK（软件开发工具包）配置、证书和账户材料。

- `config.toml.example`：示例配置，仅用于说明字段形态。
- `config.toml`：实际运行配置，不建议提交真实证书和私钥。
- `sdk/`：SDK（Software Development Kit，软件开发工具包）证书目录，来自节点的 `sdk` 目录。
- `accounts/`：账户文件目录，例如 PEM（Privacy Enhanced Mail，隐私增强邮件格式）私钥文件或 keystore（密钥库）文件。
- `contract-addresses.env`：本地合约地址环境变量文件，可选，不提交。

在 VM（Virtual Machine，虚拟机）上可按下面方式准备本地配置：

```bash
cd chain-apps/fisco-bcos-java-sdk
cp conf/config.toml.example conf/config.toml
mkdir -p conf/sdk conf/accounts
cp ~/fisco/nodes/127.0.0.1/sdk/* conf/sdk/
```

`config.toml` 中常用字段：

- `cryptoMaterial.certPath`：证书目录，默认示例为 `conf/sdk`。
- `network.peers`：节点 RPC（Remote Procedure Call，远程过程调用）地址，例如 `127.0.0.1:20200`。
- `account.keyStoreDir`：账户文件目录。未指定 `accountFilePath` 时，SDK 会按配置加载或生成本地账户材料。

合约地址不写入源码。脚本兼容以下环境变量：

```bash
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...
```

这些真实配置、证书、私钥和账户文件都被 `.gitignore` 排除。
