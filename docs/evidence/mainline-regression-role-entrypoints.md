# 主线 role entrypoints 回归验证

本记录对应 `test/mainline-production-regression` 分支，用于验证 role entrypoints（角色运行入口）合入主线后，Rust（系统级编程语言）workspace（工作区）、FISCO BCOS（金融区块链合作联盟开源区块链底层平台）链端复用、runtime（运行时）配置隔离和多角色 E2E（End-to-End，端到端）仍可闭环。验证只沉淀证据，不做功能开发。

## 基线

| 字段 | 记录 |
| --- | --- |
| 本地 worktree（工作树） | `D:/Users/Administrator/PycharmProjects/gs_tbk_wt_mainline_regression` |
| 分支 | `test/mainline-production-regression` |
| HEAD（当前提交指针） | `a20b0d2e6f7104e88279dd99f3a39e20a664a1d6` |
| HEAD 说明 | `docs(runtime): document role entrypoint flow` |
| master（主线分支）确认 | 本地仓库未配置 remote（远端仓库）；本地 `master` 与当前分支同指向 `a20b0d2` |
| VM（Virtual Machine，虚拟机） | `gstbk-vm` / `192.168.1.24` / Ubuntu 22.04.4 LTS |
| VM 源码目录 | `/tmp/gstbk-mainline-regression-verify` |
| VM 运行目录 | `/tmp/gstbk-mainline-regression-e2e` |

开始前执行：

```text
## test/mainline-production-regression
```

```text
a20b0d2 (HEAD -> test/mainline-production-regression, master) docs(runtime): document role entrypoint flow
cbe82e4 test(e2e): verify role entrypoints on vm
feb553f fix(scripts): run roles through binaries
43327a6 feat(runtime): add role run entrypoints
57e2c4a merge: runtime config isolation
3b70a17 merge: ci hardening
9cb47da test(runtime): verify isolated e2e configs on vm
26cb6c5 feat(runtime): isolate e2e configs
7e93069 ci: enforce baseline gates
6a94bce (tag: post-e2e-ops-baseline-2026-05-11) merge: fisco ops automation
```

同步方式：本地创建 Git bundle（Git 打包仓库对象），复制到 VM 后克隆并 checkout（检出）`test/mainline-production-regression`。VM 克隆后 `git status --short --branch` 只输出分支行。

## 基础门禁

| 命令 | 结果 | 日志 |
| --- | --- | --- |
| `cargo fmt --all -- --check` | 通过，退出码 `0` | `/tmp/gstbk-mainline-regression-verify-logs/cargo-fmt.log` |
| `LD_LIBRARY_PATH=$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-} cargo check --workspace --locked` | 通过，退出码 `0`；仅有历史 warning（警告）和 `llvm-config` 提示 | `/tmp/gstbk-mainline-regression-verify-logs/cargo-check.log` |
| `bash -n scripts/run-local/*.sh scripts/fisco/*.sh` | 通过，退出码 `0` | `/tmp/gstbk-mainline-regression-verify-logs/bash-syntax.log` |

## FISCO 环境

| 字段 | 记录 |
| --- | --- |
| `FISCO_CONFIG` | `/tmp/gstbk-mainline-regression-verify/chain-apps/fisco-bcos-java-sdk/conf/config.toml` |
| `FISCO_GROUP` | `group0` |
| `FISCO_CONSOLE_DIR` | `/home/gstbk/fisco/console` |
| `GSTBK_PERSONAL_INFO_APP_DIR` | `/tmp/gstbk-mainline-regression-verify/chain-apps/fisco-bcos-java-sdk` |
| `GSTBK_SIGNATURE_APP_DIR` | `/tmp/gstbk-mainline-regression-verify/chain-apps/fisco-bcos-java-sdk` |
| `PersonalInfo` 合约 | `0x6546c3571f17858ea45575e7c6457dad03e53dbb` |
| `Signature` 合约 | `0xcceef68c9b4811b32c75df284a1396c7c5509561` |

执行 `scripts/fisco/prepare-sdk-conf.sh --force` 后，从 `/home/gstbk/fisco/nodes/127.0.0.1/sdk` 复制 SDK（Software Development Kit，软件开发工具包）证书并生成被 Git（分布式版本控制系统）忽略的 `conf/config.toml`。

`scripts/fisco/doctor.sh` 结果：Java（编程语言和运行时平台）、Gradle（Java 构建工具）、console（控制台）、Java SDK 脚本、SDK 证书、4 个 `fisco-bcos` 进程和端口 `20200`、`20201`、`30300`、`30301` 均正常；`blockNumber 42`；`doctor passed: 0 warning(s)`。

## E2E 结果

执行命令：

```bash
bash scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-mainline-regression-e2e --reuse-chain --contract-addresses-from-env --timeout-seconds 300
```

结果：

| 字段 | 记录 |
| --- | --- |
| Manifest（运行清单） | `/tmp/gstbk-mainline-regression-e2e/runtime-logs/20260511T152649Z/manifest.json` |
| schema（结构版本） | `gstbk.e2e.manifest.v2` |
| script version（脚本版本） | `run-e2e.sh role-entrypoints` |
| `success` | `true` |
| 开始时间 | `2026-05-11T15:26:49Z` |
| 结束时间 | `2026-05-11T15:33:27Z` |
| 耗时 | `398` 秒 |
| 区块高度 | 运行前 `42`，完成后 `46` |
| runtime 配置 | `config.mode = "runtime"`，`config.legacy_fixture_configs = false`，`config.configs_restored = "not-applicable"` |
| runtime 配置目录 | `/tmp/gstbk-mainline-regression-e2e/runtime-state/20260511T152649Z/runtime-config` |

角色命令来自 manifest：

| 角色 | 命令 |
| --- | --- |
| Proxy（代理） | `bash scripts/run-local/run-proxy.sh` |
| Node1（管理员节点 1） | `bash scripts/run-local/run-node.sh 1` |
| Node2（管理员节点 2） | `bash scripts/run-local/run-node.sh 2` |
| Node3（管理员节点 3） | `bash scripts/run-local/run-node.sh 3` |
| Node4（管理员节点 4） | `bash scripts/run-local/run-node.sh 4` |
| User1（用户 1） | `env GSTBK_PERSONAL_INFO_PAYLOAD_PATH=/tmp/gstbk-mainline-regression-e2e/runtime-state/20260511T152649Z/identity/user1-block-personal-info.json bash scripts/run-local/run-user.sh 1` |
| User2（用户 2） | `env GSTBK_PERSONAL_INFO_PAYLOAD_PATH=/tmp/gstbk-mainline-regression-e2e/runtime-state/20260511T152649Z/identity/user2-block-personal-info.json bash scripts/run-local/run-user.sh 2` |

关键阶段均命中：Proxy 与 4 个 Node 完成 KeyGen（联合密钥生成），2 个 User 完成 Join（用户加入）和 Sign（签名），4 个 Node 完成 Verify/Open（验证/揭示），两个用户的 Signature 和 PersonalInfo 均上链并可查询。

## 链上证据

| 合约 | 用户 | TX（Transaction，交易）哈希 | 区块 | 查询 |
| --- | --- | --- | --- | --- |
| `Signature` | `e2e20260511T152649Z_user1` | `0x4ee24a1d1222c63c981fb135af5ff55e28b7dbcb592b6a41467a0552fc4b1d92` | `43` | `exists true` |
| `Signature` | `e2e20260511T152649Z_user2` | `0x841ea59cf5045cf3bdcb3f967e1f10f49d4b9dee6ad06ccdfd0183c5211d5aca` | `44` | `exists true` |
| `PersonalInfo` | `e2e20260511T152649Z_user1` | `0xbb0f96a1127dae62756bd614904b8355068f1baa4df2cc26ba9e8891873e5b8b` | `45` | `exists true` |
| `PersonalInfo` | `e2e20260511T152649Z_user2` | `0x8b0c56b3102ca25bc000fa59f1d075487a22b90e7df37c06e7699d8e180d83d7` | `46` | `exists true` |

身份密文 SHA-256（Secure Hash Algorithm 256-bit，安全哈希算法 256 位）：

| 用户 | SHA-256 |
| --- | --- |
| `e2e20260511T152649Z_user1` | `e2838b1f2506e8f1582b4db6ce9761f5d263d6bae5f025f03f6e4ffd0686349d` |
| `e2e20260511T152649Z_user2` | `6aa1029f7b3d4c86ae1716dd0bc328bdf8bf5c7737abcbc0d0d2ed9237a596cb` |

## Git 干净度

运行后在 VM 源码目录执行：

```text
## test/mainline-production-regression...origin/test/mainline-production-regression
```

`git diff` 无输出；针对 legacy config JSON（JavaScript Object Notation，数据交换格式）的 diff 也无输出。生成的 `conf/config.toml`、SDK 证书和运行态材料均处于 `.gitignore` 边界内。

## 结论

主线 `a20b0d2` 上的 role entrypoints 回归通过：基础门禁通过，复用既有 FISCO BCOS 合约完成 1 Proxy + 4 Node + 2 User E2E，manifest 记录 runtime 配置模式与默认角色脚本，链高从 `42` 增至 `46`，运行后 Git worktree 保持干净。

建议在该提交上打 tag（标签）`v0.1-engineering-prototype`，语义限定为“生产化 smoke 验证通过的工程原型”，不表述为完整生产系统。
