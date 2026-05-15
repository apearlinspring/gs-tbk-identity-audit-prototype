# 阶段 2：Java SDK 调用闭环验证记录

验证日期：2026-05-10

## 环境

- SSH（Secure Shell，安全外壳协议）入口：`gstbk-vm`，实际 hostname（主机名）为 `gs-tbk-dev`。
- 系统：Ubuntu（Linux 发行版）22.04.4 LTS。
- 用户：`gstbk`。
- Java（编程语言运行环境）：OpenJDK 11.0.30。
- FISCO BCOS（金融区块链合作联盟开源区块链底层平台）：v3.6.0。
- Console（控制台）：`/home/gstbk/fisco/console`。
- 节点 SDK（Software Development Kit，软件开发工具包）证书：`/home/gstbk/fisco/nodes/127.0.0.1/sdk`。
- Java SDK 依赖：复用 `/home/gstbk/fisco/console/lib/fisco-bcos-java-sdk-3.6.0.jar` 及同目录依赖。

## 配置准备

验证在 VM 的 `/tmp/gstbk-stage2-java-sdk` 目录中执行，未修改其他 worktree（工作树）：

```bash
cd /tmp/gstbk-stage2-java-sdk
cp conf/config.toml.example conf/config.toml
mkdir -p conf/sdk conf/accounts
cp /home/gstbk/fisco/nodes/127.0.0.1/sdk/* conf/sdk/
```

真实 `conf/config.toml`、证书和账户文件未提交。

## 构建结果

VM 无系统 Gradle（构建工具），且 `services.gradle.org` DNS（Domain Name System，域名系统）解析失败：

```text
java.net.UnknownHostException: services.gradle.org
```

因此本次通过 Windows（微软操作系统）侧下载 Gradle 8.10.2 发行包，放到 VM 的 `/tmp/gradle-8.10.2` 后构建：

```bash
cd /tmp/gstbk-stage2-java-sdk
GRADLE_USER_HOME=/tmp/gstbk-gradle-home \
FISCO_CONSOLE_DIR=/home/gstbk/fisco/console \
/tmp/gradle-8.10.2/bin/gradle --no-daemon clean build
```

结果：

```text
BUILD SUCCESSFUL in 8s
```

## 连接节点

```bash
GRADLE_USER_HOME=/tmp/gstbk-gradle-home \
FISCO_CONSOLE_DIR=/home/gstbk/fisco/console \
FISCO_CONFIG=conf/config.toml \
/tmp/gradle-8.10.2/bin/gradle --no-daemon -q personalInfo --args='blockNumber'
```

输出：

```text
blockNumber 9
```

## Wrapper 生成脚本

```bash
cd /tmp/gstbk-stage2-java-sdk
rm -rf /tmp/gstbk-stage2-generated-check
FISCO_CONSOLE_DIR=/home/gstbk/fisco/console \
  bash scripts/generate-contract-wrappers.sh /tmp/gstbk-stage2-contracts /tmp/gstbk-stage2-generated-check
```

输出：

```text
Generated wrappers under /tmp/gstbk-stage2-generated-check/org/gstbk/chain/contracts
/tmp/gstbk-stage2-generated-check/org/gstbk/chain/contracts/PersonalInfo.java
/tmp/gstbk-stage2-generated-check/org/gstbk/chain/contracts/Signature.java
```

## 合约部署

```bash
FISCO_CONFIG=conf/config.toml \
FISCO_CONSOLE_DIR=/home/gstbk/fisco/console \
/tmp/gradle-8.10.2/bin/gradle --no-daemon -q personalInfo --args='deploy'
```

输出：

```text
contractAddress 0x33e56a083e135936c1144960a708c43a661706c0
blockNumber 10
```

```bash
FISCO_CONFIG=conf/config.toml \
FISCO_CONSOLE_DIR=/home/gstbk/fisco/console \
/tmp/gradle-8.10.2/bin/gradle --no-daemon -q signature --args='deploy'
```

输出：

```text
contractAddress 0x19a6434154de51c7a7406edf312f01527441b561
blockNumber 11
```

## 直接 Gradle 调用

测试用户：`stage2_user_1778447217`。

PersonalInfo 写入：

```text
ret 0
status 0
transactionHash 0x9df8233ee1d67859777ac5818f84d1b6511b0ca7109d83520620e901b1b4f2e6
blockNumber 12
info {"ciphertext":"cl-test-stage2_user_1778447217","proof":"zkp-test","version":1}
```

PersonalInfo 查询：

```text
exists true
info {"ciphertext":"cl-test-stage2_user_1778447217","proof":"zkp-test","version":1}
```

PersonalInfo 历史查询：

```text
ret 0
info {"ciphertext":"cl-test-stage2_user_1778447217","proof":"zkp-test","version":1}
```

Signature 写入：

```text
ret 0
status 0
transactionHash 0x9fbf2bc2580abe4fe676e19af7ed6a69304128ccadb80ccc9fb90ad821e9ba80
blockNumber 13
signature {"user":"stage2_user_1778447217","message":"stage2","signature":"sigma-test"}
```

Signature 查询：

```text
exists true
signature {"user":"stage2_user_1778447217","message":"stage2","signature":"sigma-test"}
```

Signature 历史查询：

```text
ret 0
signature {"user":"stage2_user_1778447217","message":"stage2","signature":"sigma-test"}
```

## Rust 侧脚本兼容验证

测试用户：`stage2_script_1778447292`。

使用环境变量提供合约地址：

```bash
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export GRADLE_USER_HOME=/tmp/gstbk-gradle-home
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export FISCO_CONFIG=conf/config.toml
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x33e56a083e135936c1144960a708c43a661706c0
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x19a6434154de51c7a7406edf312f01527441b561
```

`info_run.sh register/query` 输出：

```text
ret 0
status 0
transactionHash 0xf8f06d3e4cf5218b468991d3e069b92d040919bc5d62c548b67c694eb9dca3f0
blockNumber 14
info {"ciphertext":"script-info-stage2_script_1778447292","proof":"zkp-script"}
exists true
info {"ciphertext":"script-info-stage2_script_1778447292","proof":"zkp-script"}
```

`signature_run.sh register/query` 输出：

```text
ret 0
status 0
transactionHash 0xf126410b58bde1991458f47657c36c0138c53f0054bce3e6855da74651170692
blockNumber 15
signature {"user":"stage2_script_1778447292","signature":"script-sigma"}
exists true
signature {"user":"stage2_script_1778447292","signature":"script-sigma"}
```

## 剩余限制

- VM 外网/DNS 不稳定，Gradle Wrapper 首次下载发行包会失败；可使用 Windows 侧下载、VM 反向代理或预装 Gradle 后设置 `GRADLE_BIN`。
- 本次验证完成 Java SDK 到链端的调用闭环，尚未重新跑 Rust 侧完整 Proxy（代理）、Node（管理员节点）、User（用户）端到端流程。
- 合约地址为本次 VM 测试地址，后续复现应通过环境变量或本地配置提供，不要硬编码到源码。
