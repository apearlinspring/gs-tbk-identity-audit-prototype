# E2E 合并前验收表

本文件汇总阶段 3.2：E2E（End-to-End，端到端）合并前生产化加固结果。详细运行记录见 `docs/evidence/e2e-repro-stage3.md`，长期摘要见 `docs/evidence/runtime-summary.md`。

## 结论

| 项目 | 结论 |
| --- | --- |
| 是否建议合入主线 | 建议合入。当前产物已经满足 production smoke（生产化冒烟验证）要求，但仍不是 daemon（守护进程）/service（服务）管理系统 |
| 成功 E2E manifest | `/tmp/gstbk-e2e-32-git-run/runtime-logs/20260511T063905Z/manifest.json` |
| Git worktree 清洁度 | 成功 `run-e2e.sh` 后仅输出分支行，无配置文件残留改动 |
| 链端 | 复用 VM（Virtual Machine，虚拟机）上已运行 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）v3.6.0 四节点 |
| 合约 | `PersonalInfo` 和 `Signature` 均完成 register/select/history 验证 |
| 多角色 | 1 Proxy（代理）+ 4 Node（管理员节点）+ 2 User（用户）跑通 KeyGen/Join/Revoke/Sign/上链/Verify/Open |

## 成功运行摘要

| 字段 | 记录 |
| --- | --- |
| 工作目录 | `/tmp/gstbk-e2e-32-git` |
| Runtime（运行时）目录 | `/tmp/gstbk-e2e-32-git-run` |
| 命令 | `bash scripts/run-local/run-e2e.sh --users 2 --nodes 4 --runtime-dir /tmp/gstbk-e2e-32-git-run --reuse-chain --contract-addresses-from-env --timeout-seconds 300` |
| Manifest schema（结构版本） | `gstbk.e2e.manifest.v2` |
| 区块高度 | `30` -> `34` |
| 角色端口 | Proxy `50000`；Node `50001` 到 `50004`；User `60001`、`60002` |
| 配置恢复 | `config.configs_restored = "true"` |
| 进程清理 | 完成后未发现上述端口监听残留 |

## 合约与交易

| 合约 | 地址 |
| --- | --- |
| `PersonalInfo` | `0x6546c3571f17858ea45575e7c6457dad03e53dbb` |
| `Signature` | `0xcceef68c9b4811b32c75df284a1396c7c5509561` |

| 合约 | 用户 | TX（Transaction，交易）哈希 | 区块 | 查询 |
| --- | --- | --- | --- | --- |
| `Signature` | `e2e20260511T063905Z_user1` | `0x929e6b566d2b95cf09d278a925c8494a6da6017606c61e007ede1554fc7369f8` | `31` | `exists true` |
| `Signature` | `e2e20260511T063905Z_user2` | `0xd8b364623a97c07422123968e79d7ce8324b08605c06e4765e321b3e0fb19a8e` | `32` | `exists true` |
| `PersonalInfo` | `e2e20260511T063905Z_user1` | `0x66aeaa0a862d3d0c0b2f44819805ab2424fe557f814da4d63b021a1b62aa5e47` | `33` | `exists true` |
| `PersonalInfo` | `e2e20260511T063905Z_user2` | `0x75c965e4f3f5ac54d12046204db3e4b328236b29cf7248ffd017793a68e99303` | `34` | `exists true` |

## 身份密文

| 用户 | SHA-256（安全哈希算法 256 位） |
| --- | --- |
| `e2e20260511T063905Z_user1` | `17491217fd54940fe6ddd540903046edaf260044adf959e0c3889388949ac473` |
| `e2e20260511T063905Z_user2` | `cf978ef8d5ff73ae7e088b94970fedb0fb04d805bd22811a0d47f1e8a8a1c670` |

## 失败场景

| 场景 | 验证结果 |
| --- | --- |
| 未传 `--reuse-chain` | 提前失败，明确说明当前脚本只支持复用已运行链 |
| 缺少合约地址且传入 `--contract-addresses-from-env` | 提前失败，manifest `success false`，错误指向缺失环境变量 |
| Proxy 端口 `50000` 被占用 | 链健康检查后、角色启动前失败，manifest `success false`，未留下角色进程 |
| 缺少 `examples/id-info/user2.json` | 渲染配置和启动角色前失败，错误指向缺失输入样例 |

## 质量门禁

| 命令 | 结果 |
| --- | --- |
| `cargo check --workspace` | 通过 |
| `cargo test -p id_info_process -- --test-threads=1` | 通过，12 个测试通过 |
| `rustfmt crates/id_info_process/src/main.rs crates/id_info_process/src/id_process.rs --check` | 通过 |
| `bash -n scripts/run-local/run-id-info.sh scripts/run-local/render-configs.sh scripts/run-local/run-e2e.sh scripts/run-local/run-node.sh scripts/run-local/run-user.sh` | 通过 |
| `shellcheck scripts/run-local/run-id-info.sh scripts/run-local/render-configs.sh scripts/run-local/run-e2e.sh scripts/run-local/run-node.sh scripts/run-local/run-user.sh` | 未执行；VM 未安装 shellcheck，apt 安装超过 300 秒未完成 |
| `git diff --check` | 通过 |

## 合并后注意

- 继续将真实证书、账户、`conf/config.toml` 和运行日志保留在 VM 或安全本地目录，不提交仓库。
- 当前 orchestrator（编排器）定位为 smoke（冒烟验证）脚本；若要长期运行，应另行引入 systemd（Linux 系统服务管理器）或容器编排。
- `render-configs.sh` 仍会写 legacy fixture 配置路径；`run-e2e.sh` 已默认备份和恢复，调试时才使用 `--keep-rendered-configs`。
