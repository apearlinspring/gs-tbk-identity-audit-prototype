# 运行证据摘要

本文汇总 2026 年 5 月的虚拟机运行结果，并列出复现入口。

## 验证范围

当时的验证覆盖：

- Rust 身份字段 CLI：`keygen`、`enc --input --output`、`verify --input`。
- Java SDK/FISCO BCOS 链端写入与查询：`register`、`select`、`history/selectWithBlockNumber`。
- 1 个 Proxy + 4 个 Node + 2 个 User 的多角色流程：KeyGen、Join、Revoke、Sign、链上 register、Node select、Verify 和 Open。
- `run-e2e.sh`：端口占用检查、超时等待、失败尾日志、trap 清理、统一日志目录、manifest 输出、必要环境变量预检和配置备份/恢复。
- `run-proxy.sh`、`run-node.sh` 和 `run-user.sh`：默认调用正式角色二进制入口；旧 `cargo test` 长运行入口仅作为显式兼容/调试路径保留。
- `gstbk-service.sh`：本地服务管理脚本，支持 PID 文件、角色日志、运行配置、运行状态、按顺序启动、反向停止、状态查看和日志 tail。
- 只读审计控制台：可读取 `examples/evidence/*.json` 和本地生成的 `docs/evidence/console-current-*.json`，展示用户、合约、交易、查询、Verify/Open 和失败场景摘要。

## 复现入口

基础构建：

```bash
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"
cargo build --workspace
```

身份字段：

```bash
bash scripts/run-local/run-id-info.sh keygen
bash scripts/run-local/run-id-info.sh enc --input examples/id-info/user1.json
bash scripts/run-local/run-id-info.sh verify --input /tmp/gstbk-runtime-state/user1-block-personal-info.json
```

链端 E2E：

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x...
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0x...

bash scripts/run-local/run-e2e.sh \
  --users 2 \
  --nodes 4 \
  --runtime-dir /tmp/gstbk-e2e-smoke \
  --reuse-chain \
  --contract-addresses-from-env
```

链上审计摘要：

```bash
bash scripts/evidence/run-audit-query-demo.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json \
  --output-dir /tmp/gstbk-audit-query-summary

bash scripts/evidence/run-malicious-open-demo.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json \
  --output-dir /tmp/gstbk-malicious-open-summary
```

控制台当前证据：

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-smoke/runtime-logs/<timestamp>/manifest.json
```

## 使用范围

这些结果来自工程原型的冒烟验证。角色入口复用 `intergration_test` 中的流程模块，`gstbk-service.sh` 提供本地进程管理。新 E2E 推荐使用独立运行配置目录，旧测试配置保留兼容路径。

链端完整验证需在目标环境重新运行。长期部署还需要权限控制、监控告警、恢复和密钥管理。

## 常见异常

| 问题 | 判断 | 处理 |
| --- | --- | --- |
| Gradle 下载 Maven 依赖失败 | 环境网络问题 | 设置 `FISCO_CONSOLE_DIR` 复用 console 自带 `lib/*.jar`，或设置 `GRADLE_BIN` 指向本地 Gradle。 |
| `cargo fmt --check` 失败 | 源码格式不一致 | 用 `cargo fmt` 整理后复查。 |
| 缺少合约地址且传入 `--contract-addresses-from-env` | 配置问题 | 预检应提前失败，补齐 `GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS` 和 `GSTBK_SIGNATURE_CONTRACT_ADDRESS`。 |
| 端口被占用 | 环境问题 | 先确认是否有其他任务在跑，再决定换端口或等待。 |
| 缺少 User 身份字段输入样例 | 输入配置问题 | 使用 `examples/id-info/user1.json` / `user2.json`，或通过环境变量提供独立脱敏输入。 |
