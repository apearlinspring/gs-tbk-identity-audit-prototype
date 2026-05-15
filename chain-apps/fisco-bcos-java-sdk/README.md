# FISCO BCOS Java SDK 调用层

本目录用于补齐链端 Java SDK（Software Development Kit，软件开发工具包）调用层。当前版本已对齐 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）v3.6.0，并内置 `PersonalInfo` 与 `Signature` 合约 wrapper（包装类）。

## 目录

```text
.
├── build.gradle
├── conf/
│   ├── README.md
│   └── config.toml.example
├── gradlew / gradlew.bat
├── info_run.sh
├── signature_run.sh
├── scripts/
│   └── generate-contract-wrappers.sh
└── src/main/java/org/gstbk/chain/
    ├── ChainContext.java
    ├── ContractCommandRunner.java
    ├── ContractInvoker.java
    ├── PersonalInfoClient.java
    ├── SignatureClient.java
    └── contracts/
        ├── PersonalInfo.java
        └── Signature.java
```

## 准备配置

先准备真实 `conf/config.toml`、SDK 证书和账户目录。不要提交真实配置、证书、私钥或账户文件。

```bash
cd chain-apps/fisco-bcos-java-sdk
cp conf/config.toml.example conf/config.toml
mkdir -p conf/sdk conf/accounts
cp ~/fisco/nodes/127.0.0.1/sdk/* conf/sdk/
```

常用环境变量：

```bash
export FISCO_CONFIG=conf/config.toml
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=$HOME/fisco/console
```

如果 VM（Virtual Machine，虚拟机）没有系统 Gradle（构建工具）且外网不可用，可先在可联网机器下载 Gradle 发行包，解压后用 `GRADLE_BIN` 指定：

```bash
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
```

## 构建

有网络时可直接使用 Gradle Wrapper（Gradle 包装器）：

```bash
./gradlew clean build
```

在 FISCO BCOS console（控制台）已部署的 VM 上，推荐复用 console 自带的 v3.6.0 jar（Java 归档文件）：

```bash
FISCO_CONSOLE_DIR=$HOME/fisco/console ./gradlew clean build
```

## 生成合约 Wrapper

仓库已提交通过 v3.6.0 工具链生成的类：

- `org.gstbk.chain.contracts.PersonalInfo`
- `org.gstbk.chain.contracts.Signature`

如合约变更，可重新生成：

```bash
FISCO_CONSOLE_DIR=$HOME/fisco/console \
  ./scripts/generate-contract-wrappers.sh ../../contracts/fisco-bcos
```

脚本使用 console 内置编译器和 `bcos-code-generator`，不会部署合约。

## 运行示例

先准备 `conf/config.toml`，再执行：

```bash
./gradlew personalInfo --args="blockNumber"
./gradlew personalInfo --args="deploy"
./gradlew personalInfo --args="register 0xCONTRACT_ADDRESS user1 path-or-json"
./gradlew personalInfo --args="select 0xCONTRACT_ADDRESS user1"
./gradlew personalInfo --args="history 0xCONTRACT_ADDRESS user1 100"

./gradlew signature --args="blockNumber"
./gradlew signature --args="deploy"
./gradlew signature --args="register 0xCONTRACT_ADDRESS user1 path-or-json"
./gradlew signature --args="select 0xCONTRACT_ADDRESS user1"
./gradlew signature --args="history 0xCONTRACT_ADDRESS user1 100"
```

`register` 的第三个参数可以是紧凑 JSON（JavaScript Object Notation，数据交换格式）、文件路径或 `@file`。

## Rust 调用脚本

Rust（系统级编程语言）侧可把目录环境变量指向本目录：

```bash
export GSTBK_PERSONAL_INFO_APP_DIR=/path/to/chain-apps/fisco-bcos-java-sdk
export GSTBK_SIGNATURE_APP_DIR=/path/to/chain-apps/fisco-bcos-java-sdk
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...
```

兼容旧脚本参数：

```bash
bash info_run.sh register user1 /path/to/personal_info.json
bash info_run.sh select user1

bash signature_run.sh register user1 /path/to/signature_info.json
bash signature_run.sh select user1
```

`query` 是 `select` 的别名；输出会包含 `info <json>` 或 `signature <json>`，便于 Rust 侧解析。Rust 调用层会在执行脚本前检查合约地址和脚本路径，并在 Java SDK 返回失败时保留 stdout（标准输出）和 stderr（标准错误）。

## VM 验证记录

阶段 2 的实测命令和结果见 [docs/evidence/fisco-java-sdk-stage2.md](../../docs/evidence/fisco-java-sdk-stage2.md)。
