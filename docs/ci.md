# CI 检查

GitHub Actions 工作流位于 `.github/workflows/ci.yml`，负责构建、格式和脚本检查。链端部署与多角色 E2E 需要在配置好 FISCO BCOS 的环境中另行运行；2026-05-11 的虚拟机链端验证和 2026-05-12 的 Rust 构建记录见[运行证据摘要](evidence/runtime-summary.md)。

## 检查项目

| 项目 | 内容 |
| --- | --- |
| Rust 格式 | `cargo fmt --all -- --check`。 |
| Rust 构建 | 设置 `LD_LIBRARY_PATH` 后执行 `cargo build --workspace --locked`，检查工作区编译及 `libencrypt.so` 链接。 |
| Java SDK | `gradle --no-daemon build`，编译合约包装类、客户端和脚本调用层。构建前确认 `conf/config.toml` 和 `conf/sdk` 不存在。 |
| Bash 语法 | 对 `scripts/run-local/*.sh`、`scripts/fisco/*.sh`、`scripts/ci/*.sh` 逐个执行 `bash -n`。 |
| ShellCheck | 检查上述 Bash 脚本。 |
| Solidity | 检查 `PersonalInfo.sol`、`Signature.sol`、`Table.sol` 的基础声明。 |
| 合约接口一致性 | 对照 Solidity、ABI、Java 包装类、客户端、Gradle 任务和调用脚本。 |
| 审计台 | `node --check` 检查服务端与前端语法，`npm run check` 检查证据聚合。 |

这些检查失败时，工作流会报错。Rust 构建使用已提交的 `Cargo.lock`；在 2026-05-12 的 Ubuntu 虚拟机验证通过后，工作流从 `cargo check --workspace --locked` 升级为 `cargo build --workspace --locked`。

Bash 语法检查使用循环逐个处理文件，因为 `bash -n file1 file2` 只解析第一个文件，其余文件会成为位置参数。ShellCheck 目前仅在 `gstbk-service.sh` 局部关闭 SC2016：该处的 `bash -c 'cd "$1" ... exec "$@"'` 需要由子 Bash 接收参数后展开。

## 本地复核

审计台无额外 npm 依赖，运行：

```bash
node --check apps/audit-console/server.mjs
node --check apps/audit-console/public/app.js
npm run check --prefix apps/audit-console
```

`npm run check` 聚合 `examples/evidence/*.json` 与 `docs/evidence/*.json`，检查 JSON 结构和读取结果。

合约接口检查：

```bash
bash scripts/ci/check-contract-wrapper-consistency.sh
```

此检查使用仓库源码。若本机已有 FISCO BCOS console 工具链，可以重新生成包装类到临时目录，再与已提交的版本比较：

```bash
GSTBK_CHECK_GENERATED_WRAPPERS=1 FISCO_CONSOLE_DIR=/path/to/console \
  bash scripts/ci/check-contract-wrapper-consistency.sh
```

Java 构建遇到 Maven 下载问题时，可以设置 `FISCO_CONSOLE_DIR`，让 Gradle 使用 console 自带的 jar。

CI 不启动链节点或多角色协议。需要检查部署、`register` / `select` / `history`、Verify/Open 和交易回执时，按[运行手册](operations/README.md)在目标环境运行 E2E，并保存该次运行的结果。
