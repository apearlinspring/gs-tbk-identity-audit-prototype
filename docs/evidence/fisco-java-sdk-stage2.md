# 阶段 2：Java SDK 调用闭环验证记录

阶段 2 完成了 Java SDK 调用联调，覆盖包装类生成、Gradle 构建、节点连接、合约部署、`register`、`select`、`history/selectWithBlockNumber` 和 Rust 调用脚本。

## 环境要求

- Ubuntu 或等价 Linux 环境。
- OpenJDK 11。
- FISCO BCOS v3.6.0。
- 可访问的 FISCO BCOS 节点 SDK 证书目录。
- Gradle 8.x，或通过 `FISCO_CONSOLE_DIR` 复用 console 自带 jar 依赖。

## 配置准备

```bash
cd chain-apps/fisco-bcos-java-sdk
cp conf/config.toml.example conf/config.toml
mkdir -p conf/sdk conf/accounts
cp /path/to/fisco/nodes/127.0.0.1/sdk/* conf/sdk/
```

配置和证书的准备方式见[配置与密钥管理](../operations/secrets-and-config.md)。

## 构建

```bash
export FISCO_CONSOLE_DIR=/path/to/fisco/console
export GRADLE_BIN=/path/to/gradle/bin/gradle

"${GRADLE_BIN:-./gradlew}" --no-daemon clean build
```

## 节点连接

```bash
FISCO_CONFIG=conf/config.toml \
FISCO_GROUP=group0 \
"${GRADLE_BIN:-./gradlew}" --no-daemon -q personalInfo --args='blockNumber'
```

能输出 `blockNumber <number>` 即说明 Java SDK 已能连接目标 group。

## 包装类生成

```bash
FISCO_CONSOLE_DIR=/path/to/fisco/console \
  bash scripts/generate-contract-wrappers.sh /tmp/gstbk-contracts /tmp/gstbk-generated-wrappers
```

预期生成：

```text
org/gstbk/chain/contracts/PersonalInfo.java
org/gstbk/chain/contracts/Signature.java
```

## 合约调用闭环

部署：

```bash
FISCO_CONFIG=conf/config.toml "${GRADLE_BIN:-./gradlew}" --no-daemon -q personalInfo --args='deploy'
FISCO_CONFIG=conf/config.toml "${GRADLE_BIN:-./gradlew}" --no-daemon -q signature --args='deploy'
```

直接 Gradle 调用应覆盖：

- `personalInfo register`
- `personalInfo select`
- `personalInfo history` / `selectWithBlockNumber`
- `signature register`
- `signature select`
- `signature history` / `selectWithBlockNumber`

Rust 侧脚本兼容：

```bash
export FISCO_CONFIG=conf/config.toml
export FISCO_GROUP=group0
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...

./info_run.sh register user1 /path/to/personal-info.json
./info_run.sh select user1
./signature_run.sh register user1 /path/to/signature.json
./signature_run.sh select user1
```

## 验收结论

- Java SDK 调用层能构建并连接 FISCO BCOS group。
- 生成脚本能输出 `PersonalInfo` 与 `Signature` 的 Java 包装类。
- 两个合约的部署、写入、查询和历史查询路径已完成验证。
- `info_run.sh` 与 `signature_run.sh` 兼容 Rust 侧历史脚本参数。
- 合约地址通过环境变量或本地配置提供。
