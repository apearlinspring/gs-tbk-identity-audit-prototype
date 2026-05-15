# 阶段 3 E2E 复现记录

本文记录 2026-05-11 在 `gstbk-vm` 上完成的 E2E（End-to-End，端到端）闭环复现。原始日志保存在 VM（Virtual Machine，虚拟机）临时目录 `/tmp/gstbk-e2e-smoke`，仓库只保留摘要和可复现命令。

## 开始前基线状态

本地 worktree（工作树）：

```bash
git status --short --branch
git log --oneline --decorate -n 10
git log --oneline master..HEAD
git log --oneline HEAD..master
```

结果：

- 当前分支：`test/e2e-repro`。
- 阶段 3 初次复现开始前，分支基线来自已合入 Rust（系统级编程语言）身份字段修复后的主线；当时的共同基线提交为 `eaa3c0a docs(rust): document identity plaintext mapping`。
- 后续本分支新增 E2E 修复、运行证据和阶段 3.1 生产化加固提交，因此不再表述为“HEAD 与 master 同点”或“master..HEAD 为空”。

## VM 准备

使用 Windows PowerShell（微软命令行外壳）/ OpenSSH（开放安全外壳协议）：

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
ssh gstbk-vm
```

干净复现目录：

```bash
rm -rf /tmp/gstbk-e2e-smoke /tmp/gstbk-e2e-smoke.tar
mkdir -p /tmp/gstbk-e2e-smoke
tar -xf /tmp/gstbk-e2e-smoke.tar -C /tmp/gstbk-e2e-smoke
```

Java SDK（Software Development Kit，软件开发工具包）配置：

```bash
app=/tmp/gstbk-e2e-smoke/chain-apps/fisco-bcos-java-sdk
mkdir -p "$app/conf/sdk" "$app/conf/accounts"
cp /home/gstbk/fisco/nodes/127.0.0.1/sdk/ca.crt "$app/conf/sdk/"
cp /home/gstbk/fisco/nodes/127.0.0.1/sdk/sdk.crt "$app/conf/sdk/"
cp /home/gstbk/fisco/nodes/127.0.0.1/sdk/sdk.key "$app/conf/sdk/"
cp "$app/conf/config.toml.example" "$app/conf/config.toml"
# 将 certPath 改为 /tmp/gstbk-e2e-smoke/chain-apps/fisco-bcos-java-sdk/conf/sdk
```

Gradle（构建工具）离线依赖：

```bash
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
```

`FISCO_CONSOLE_DIR` 用于复用 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）console（控制台）自带的 `lib/*.jar`，避免 VM DNS（Domain Name System，域名系统）不稳定时下载 Maven（Java 依赖仓库）失败。

## 环境检查

```bash
java -version
/tmp/gradle-8.10.2/bin/gradle -v
rustc --version
cargo --version
gcc --version
g++ --version
make --version
gp -v
bison --version
clang --version
dpkg -l libgmp-dev libclang-dev
```

摘要：

- OpenJDK 11.0.30，Gradle 8.10.2。
- `rustc 1.75.0`，`cargo 1.75.0`。
- `gcc/g++ 11.4.0`，GNU Make 4.3。
- GMP（GNU Multiple Precision Arithmetic Library，多精度算术库）`libgmp-dev 6.2.1`。
- PARI/GP（数论计算系统）命令可用。
- Bison 3.8.2，Clang/libclang 14。

FISCO BCOS：

```bash
ps -eo pid,cmd | grep '[f]isco-bcos'
ss -ltnp | grep -E '20200|20201|30300|30301'
cd /home/gstbk/fisco/console && bash console.sh getBlockNumber
```

结果：

- 4 个 `fisco-bcos` 进程运行中。
- `20200`、`20201`、`30300`、`30301` 监听中。
- `getBlockNumber` 最终返回 `18`。

## 构建检查

```bash
cd /tmp/gstbk-e2e-smoke
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"
cargo fmt --check
cargo check --workspace
```

结果：

- `cargo fmt --check` 失败，rustfmt 报 873 处历史格式差异，主要是尾随空格和旧格式。该问题不影响阶段 3 运行，本轮未做全仓格式化。
- `cargo check --workspace` 通过，用时约 3 分 44 秒；存在历史 warning（警告）和 `llvm-config` 提示。

## 合约部署和 Java SDK 验证

环境变量：

```bash
cd /tmp/gstbk-e2e-smoke/chain-apps/fisco-bcos-java-sdk
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export FISCO_CONFIG=/tmp/gstbk-e2e-smoke/chain-apps/fisco-bcos-java-sdk/conf/config.toml
export FISCO_GROUP=group0
```

部署：

```bash
./info_run.sh deploy
./signature_run.sh deploy
```

结果：

- `PersonalInfo`: `0x6546c3571f17858ea45575e7c6457dad03e53dbb`，部署后区块 `7`。
- `Signature`: `0xcceef68c9b4811b32c75df284a1396c7c5509561`，部署后区块 `8`。

写入和查询：

```bash
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x6546c3571f17858ea45575e7c6457dad03e53dbb
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0xcceef68c9b4811b32c75df284a1396c7c5509561

./info_run.sh register stage3-sdk-user /tmp/gstbk-e2e-smoke/evidence/personal-sdk.json
./info_run.sh select stage3-sdk-user
./info_run.sh history stage3-sdk-user 9
./info_run.sh register stage3-sdk-user /tmp/gstbk-e2e-smoke/evidence/personal-sdk.json

./signature_run.sh register stage3-sdk-user /tmp/gstbk-e2e-smoke/evidence/signature-sdk.json
./signature_run.sh select stage3-sdk-user
./signature_run.sh history stage3-sdk-user 11
```

关键结果：

- `PersonalInfo register`: TX `0x648b9cdc5ff24ae5db871d146ab42f1a1057789e5aceb663ad207f6b39e28555`，区块 `9`。
- `PersonalInfo` 重复注册：TX `0xde03cd4aa200f069afa81ef5179440c6c42774f0329471158e102b71ac0294b6`，区块 `10`，合约返回成功。
- `Signature register`: TX `0x35356afb265bbdcccc309a5fb0248ff1b080984067f0867a1f3371ec5283a8c3`，区块 `11`。
- `select` 返回 `exists true`，`history` 返回 `ret 0`，样例 JSON 原样查回。

## Rust 身份字段加密和写链

```bash
cd /tmp/gstbk-e2e-smoke
export GSTBK_RUNTIME_DIR=/tmp/gstbk-e2e-smoke/runtime-state
export GSTBK_CL_KEYPAIR_PATH=/tmp/gstbk-e2e-smoke/runtime-state/cl_keypair.json
export LD_LIBRARY_PATH=/tmp/gstbk-e2e-smoke/crates/cl_encrypt:${LD_LIBRARY_PATH:-}
bash scripts/run-local/run-id-info.sh keygen
bash scripts/run-local/run-id-info.sh enc
```

结果：

- `keygen`: `test id_process::keygen ... ok`，生成 `cl_keypair.json`，673 bytes。
- `enc`: `test id_process::enc_prove_test ... ok`，输出 `哟西，验证通过`。
- 输出文件：`/tmp/gstbk-e2e-smoke/runtime-state/block_personal_info.json`，1472 bytes。

写链：

```bash
cd /tmp/gstbk-e2e-smoke/chain-apps/fisco-bcos-java-sdk
./info_run.sh register stage3-rust-user /tmp/gstbk-e2e-smoke/runtime-state/block_personal_info.json
./info_run.sh select stage3-rust-user
./info_run.sh history stage3-rust-user 12
```

结果：

- TX `0xef6abadb306536fed0ab66bc2da6e609d59a237b24904f4d514a76915a25a6ba`，区块 `12`。
- `select` / `history` 返回 `id_enc`、`zkp_proof`、`commitment`、`other_info`，字段结构保持一致。

## 多角色 E2E

本轮做了 3 个 E2E 必需的小修复：

- 将 `crates/intergration_test` 中 Proxy、Node1、Node4 的旧 `172.28.*` 地址改为 `127.0.0.1`。
- `run-node.sh` / `run-user.sh` 启动前创建被 Git 忽略的 `info/` 状态目录。
- `run-user.sh` 支持 `GSTBK_PERSONAL_INFO_PAYLOAD_PATH`，把 Rust 生成的身份密文 JSON 复制为 `personal_info.json`。

运行环境：

```bash
export GSTBK_REPO_ROOT=/tmp/gstbk-e2e-smoke
export GSTBK_RUNTIME_DIR=/tmp/gstbk-e2e-smoke/runtime-state
export GSTBK_CL_KEYPAIR_PATH=/tmp/gstbk-e2e-smoke/runtime-state/cl_keypair.json
export GSTBK_PERSONAL_INFO_PAYLOAD_PATH=/tmp/gstbk-e2e-smoke/runtime-state/block_personal_info.json
export LD_LIBRARY_PATH=/tmp/gstbk-e2e-smoke/crates/cl_encrypt:${LD_LIBRARY_PATH:-}
export GSTBK_PERSONAL_INFO_APP_DIR=/tmp/gstbk-e2e-smoke/chain-apps/fisco-bcos-java-sdk
export GSTBK_SIGNATURE_APP_DIR=/tmp/gstbk-e2e-smoke/chain-apps/fisco-bcos-java-sdk
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x6546c3571f17858ea45575e7c6457dad03e53dbb
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0xcceef68c9b4811b32c75df284a1396c7c5509561
export FISCO_CONFIG=/tmp/gstbk-e2e-smoke/chain-apps/fisco-bcos-java-sdk/conf/config.toml
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
```

启动顺序：

```bash
bash scripts/run-local/run-proxy.sh
bash scripts/run-local/run-node.sh 1
bash scripts/run-local/run-node.sh 2
bash scripts/run-local/run-node.sh 3
bash scripts/run-local/run-node.sh 4
bash scripts/run-local/run-user.sh 1
bash scripts/run-local/run-user.sh 2
```

监听证据：

```text
0.0.0.0:50000  Proxy
0.0.0.0:50001  Node1
0.0.0.0:50002  Node2
0.0.0.0:50003  Node3
0.0.0.0:50004  Node4
0.0.0.0:60001  User1
0.0.0.0:60002  User2
```

关键日志：

```text
Proxy: Keygen phase is staring! / Keygen phase is finished!
Proxy: Revoke phase is starting! / Revoke phase is finished!
Node1..4: Keygen phase is finished!
Node1..4: Signature query stdout: exists true
Node1..4: Open Phase is starting / Open phase is finished!
User1/User2: Join phase is starting! / Join phase is finished!
User1/User2: Sign phase is starting! / Sign phase is finished!
```

上链结果：

| 合约 | 用户 | TX（Transaction，交易）哈希 | 区块 |
| --- | --- | --- | --- |
| `Signature` | `user1_test_32` | `0x4831956812293b7791e80aad980223107ffab4cea3ef9da03b29173918cd6dd5` | `15` |
| `Signature` | `user2_test_32` | `0x1e5f8bfe0ccc200323d48dfcd95ec8b08855548403c95369827ee882caea086d` | `16` |
| `PersonalInfo` | `user1_test_32` | `0x75b0dada2cc35fa0b2b3a9e025047e88c23b0aa49f24def12b07dab0ac0ddf95` | `17` |
| `PersonalInfo` | `user2_test_32` | `0xac105dc8ee22f849a6b4915995dffa355f8d9555c5c579cb0de96941388577bd` | `18` |

查询复核：

```bash
./signature_run.sh select user1_test_32
./signature_run.sh history user1_test_32 15
./signature_run.sh select user2_test_32
./signature_run.sh history user2_test_32 16
./info_run.sh select user1_test_32
./info_run.sh history user1_test_32 17
./info_run.sh select user2_test_32
./info_run.sh history user2_test_32 18
```

摘要：

| 输出 | 结果 |
| --- | --- |
| `user1-signature-select.out` | `exists true`，3463 bytes，SHA-256 前缀 `1097db9fa6738b00` |
| `user1-signature-history.out` | `ret 0`，3463 bytes，SHA-256 前缀 `1097db9fa6738b00` |
| `user2-signature-select.out` | `exists true`，3462 bytes，SHA-256 前缀 `de2d52c6e48fdb7d` |
| `user2-signature-history.out` | `ret 0`，3462 bytes，SHA-256 前缀 `de2d52c6e48fdb7d` |
| `user1-info-select.out` | `exists true`，1434 bytes，SHA-256 前缀 `3ec527ef53eb8646` |
| `user1-info-history.out` | `ret 0`，1434 bytes，SHA-256 前缀 `3ec527ef53eb8646` |
| `user2-info-select.out` | `exists true`，1434 bytes，SHA-256 前缀 `3ec527ef53eb8646` |
| `user2-info-history.out` | `ret 0`，1434 bytes，SHA-256 前缀 `3ec527ef53eb8646` |

## 阶段 3.1 生产化加固复跑

阶段 3.1 的目标不是再次手工证明能跑，而是将流程固化为可重复、可审计、少手工的 smoke（冒烟验证）流程。

新增入口：

- `id_info_process` 正式 CLI（Command Line Interface，命令行接口）：`keygen`、`enc --input <json> --output <json>`、`verify --input <json>`。
- `examples/id-info/user1.json` 与 `examples/id-info/user2.json`：合成测试身份字段，避免两个 User（用户）复用同一份身份密文。
- `scripts/run-local/render-configs.sh`：生成 local / multi-host 配置。
- `scripts/run-local/run-e2e.sh`：端口检查、角色启动、关键日志等待、失败尾日志、trap 清理、链上 select 复核和 manifest 生成。

编排命令：

```bash
cd /tmp/gstbk-e2e-smoke
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export FISCO_CONFIG=$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml
export FISCO_GROUP=group0
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x6546c3571f17858ea45575e7c6457dad03e53dbb
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0xcceef68c9b4811b32c75df284a1396c7c5509561

bash scripts/run-local/run-e2e.sh \
  --users 2 \
  --nodes 4 \
  --runtime-dir /tmp/gstbk-e2e-31 \
  --reuse-chain \
  --contract-addresses-from-env \
  --timeout-seconds 300
```

编排结果：

| 字段 | 结果 |
| --- | --- |
| 日志目录 | `/tmp/gstbk-e2e-31/runtime-logs/20260511T054903Z` |
| Manifest | `/tmp/gstbk-e2e-31/runtime-logs/20260511T054903Z/manifest.json` |
| 区块高度 | 编排前 `22`，编排后 `26` |
| 进程清理 | 完成后 `50000`、`50001` 到 `50004`、`60001`、`60002` 无监听残留 |
| 身份密文 | user1 SHA-256 `3f57de86d737695d563dde12b78c953eed512cc4ab012cdc45e1df2803f10c18`；user2 SHA-256 `41711e44919b498c370b256e58c548c5c29e223d381312a56c8d4da733ccfe83` |

链上写入：

| 合约 | 用户 | TX（Transaction，交易）哈希 | 区块 |
| --- | --- | --- | --- |
| `Signature` | `e2e20260511T054903Z_user1` | `0x35f69ac7e206b2533a21c152a4855735d525b319dcd454670f09aaf75a89546a` | `23` |
| `Signature` | `e2e20260511T054903Z_user2` | `0x56b94d51fbc148f063ae1e60e5b4b1cc7aa4f68eb343060e07b0c031ecd45fa6` | `24` |
| `PersonalInfo` | `e2e20260511T054903Z_user1` | `0x001676a51ff35b4e42d8ba578e9fa37eb0365e63875ab752dfbe87dfbee482b8` | `25` |
| `PersonalInfo` | `e2e20260511T054903Z_user2` | `0x0bf98e678d2d52c84ec3a75e515cfad8c1344667aa07620d31d70308acc5d1a6` | `26` |

链上复核：

```bash
./signature_run.sh select e2e20260511T054903Z_user1
./signature_run.sh select e2e20260511T054903Z_user2
./info_run.sh select e2e20260511T054903Z_user1
./info_run.sh select e2e20260511T054903Z_user2
```

四次 `select` 均返回 `exists true`。`manifest.json` 记录了日志路径、身份密文路径、合约地址、TX、区块高度和 SHA-256 摘要，可作为审计入口。

## 阶段 3.2 合并前生产化加固

阶段 3.2 的目标是确认一键编排脚本在合并前具备可审计、可失败、可恢复的工程属性：成功时能用 manifest（运行清单）复核真实执行，失败时能提前退出并说明原因，运行后不污染 Git worktree（工作树）。

脚本加固点：

- `run-e2e.sh` 要求显式传入 `--reuse-chain`；当前版本只复用已运行链，未传该参数会提前报错，不会隐式启动或重建 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）。
- 使用 `--reuse-chain` 时先通过 Java SDK（Software Development Kit，软件开发工具包）包装脚本执行 `blockNumber` 链健康检查。
- 启动角色前校验 `FISCO_CONFIG`、`FISCO_GROUP`、`GSTBK_PERSONAL_INFO_APP_DIR`、`GSTBK_SIGNATURE_APP_DIR`；使用 `--contract-addresses-from-env` 时额外校验两个合约地址。
- 启动角色前检查端口和 User（用户）身份字段输入样例；失败时写入 `success false` manifest，并且不启动 Proxy（代理）/Node（管理员节点）/User。
- 启动前备份 `render-configs.sh` 改写的 local smoke fixture（本地冒烟夹具）配置，`EXIT` 默认恢复；调试时可用 `--keep-rendered-configs` 保留。

Manifest schema（结构版本）升级为 `gstbk.e2e.manifest.v2`，新增或明确记录：

| 字段 | 用途 |
| --- | --- |
| `schema_version` / `script_version` | 识别清单结构和脚本版本 |
| `start_timestamp` / `end_timestamp` / `elapsed_seconds` | 复核执行窗口和耗时 |
| `command` | 记录真实命令行，避免硬编码拼接错误参数 |
| `success` / `error` | 成功或失败结论，以及失败原因 |
| `git` / `source_snapshot` | Git 仓库记录 branch/commit/status；非 Git 快照记录关键文件 SHA-256 |
| `ports` | Proxy、Node、User 端口矩阵 |
| `contracts` / `block_before` / `block_after` | 合约地址和链健康检查前后区块高度 |
| `roles` | 角色日志路径和 SHA-256 摘要 |
| `identity` | user1/user2 身份密文路径和 SHA-256 |
| `chain_results` | Signature/PersonalInfo 写链 TX（Transaction，交易）哈希、区块和 select 复核结果 |

成功复跑命令：

```bash
cd /tmp/gstbk-e2e-32-git
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export FISCO_CONFIG=$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml
export FISCO_GROUP=group0
export GSTBK_PERSONAL_INFO_APP_DIR=$PWD/chain-apps/fisco-bcos-java-sdk
export GSTBK_SIGNATURE_APP_DIR=$PWD/chain-apps/fisco-bcos-java-sdk
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x6546c3571f17858ea45575e7c6457dad03e53dbb
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0xcceef68c9b4811b32c75df284a1396c7c5509561

bash scripts/run-local/run-e2e.sh \
  --users 2 \
  --nodes 4 \
  --runtime-dir /tmp/gstbk-e2e-32-git-run \
  --reuse-chain \
  --contract-addresses-from-env \
  --timeout-seconds 300
```

成功复跑结果：

| 字段 | 结果 |
| --- | --- |
| Manifest | `/tmp/gstbk-e2e-32-git-run/runtime-logs/20260511T063905Z/manifest.json` |
| Manifest 结论 | `success true`，耗时 `398` 秒 |
| 区块高度 | 编排前 `30`，编排后 `34` |
| 配置恢复 | `config.configs_restored = "true"` |
| Git 状态 | 运行后 `git status --short --branch` 仅输出 `## test/e2e-repro...origin/test/e2e-repro` |
| 进程清理 | 完成后 `50000`、`50001` 到 `50004`、`60001`、`60002` 无监听残留 |

链上写入：

| 合约 | 用户 | TX 哈希 | 区块 |
| --- | --- | --- | --- |
| `Signature` | `e2e20260511T063905Z_user1` | `0x929e6b566d2b95cf09d278a925c8494a6da6017606c61e007ede1554fc7369f8` | `31` |
| `Signature` | `e2e20260511T063905Z_user2` | `0xd8b364623a97c07422123968e79d7ce8324b08605c06e4765e321b3e0fb19a8e` | `32` |
| `PersonalInfo` | `e2e20260511T063905Z_user1` | `0x66aeaa0a862d3d0c0b2f44819805ab2424fe557f814da4d63b021a1b62aa5e47` | `33` |
| `PersonalInfo` | `e2e20260511T063905Z_user2` | `0x75c965e4f3f5ac54d12046204db3e4b328236b29cf7248ffd017793a68e99303` | `34` |

身份密文：

| 用户 | SHA-256 |
| --- | --- |
| `e2e20260511T063905Z_user1` | `17491217fd54940fe6ddd540903046edaf260044adf959e0c3889388949ac473` |
| `e2e20260511T063905Z_user2` | `cf978ef8d5ff73ae7e088b94970fedb0fb04d805bd22811a0d47f1e8a8a1c670` |

失败场景验证：

| 场景 | 命令摘要 | 结果 | Manifest |
| --- | --- | --- | --- |
| 未传 `--reuse-chain` | 去掉 `--reuse-chain` | 提前失败：`run-e2e.sh currently supports --reuse-chain only...` | 该错误发生在 runtime 目录创建前 |
| 缺少合约地址 | 保留 `--contract-addresses-from-env`，unset 两个地址 | 提前失败：缺少 `GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS` | `/tmp/gstbk-e2e-32-fail-missing-contract/runtime-logs/20260511T063335Z/manifest.json` |
| 端口占用 | 用 Python 临时占用 `127.0.0.1:50000` | 链健康检查后、角色启动前失败：`Port already in use: 50000` | `/tmp/gstbk-e2e-32-fail-port/runtime-logs/20260511T063358Z/manifest.json` |
| 缺少 User 输入样例 | 临时移走 `examples/id-info/user2.json` | 渲染配置和启动角色前失败，错误指向缺失文件 | `/tmp/gstbk-e2e-32-fail-user-input/runtime-logs/20260511T063428Z/manifest.json` |

质量门禁：

| 命令 | 结果 |
| --- | --- |
| `cargo check --workspace` | 通过，存在历史 warning（警告） |
| `cargo test -p id_info_process -- --test-threads=1` | 通过，12 个测试通过 |
| `rustfmt crates/id_info_process/src/main.rs crates/id_info_process/src/id_process.rs --check` | 通过 |
| `bash -n scripts/run-local/run-id-info.sh scripts/run-local/render-configs.sh scripts/run-local/run-e2e.sh scripts/run-local/run-node.sh scripts/run-local/run-user.sh` | 通过 |
| `shellcheck scripts/run-local/run-id-info.sh scripts/run-local/render-configs.sh scripts/run-local/run-e2e.sh scripts/run-local/run-node.sh scripts/run-local/run-user.sh` | 未执行；VM 未安装 shellcheck，`apt-get install shellcheck` 超过 300 秒未完成 |
| `git diff --check` | 通过 |

分支新增提交列表：

```text
9c57258 fix(e2e): harden orchestrator manifest and prechecks
d31fe56 docs(e2e): update production smoke evidence
d83e166 feat(id-info): add command line keygen and encryption flow
fd3cdeb feat(e2e): add managed local orchestrator
0a05246 docs(e2e): record stage3 runtime evidence
a2339eb fix(e2e): stabilize local run scripts
```

## 剩余风险

- `cargo fmt --check` / `cargo fmt -p id_info_process --check` 仍失败，属于历史格式债；本次只用 `rustfmt` 检查触碰的 Rust 文件。
- 本轮没有重建 FISCO BCOS 链，区块高度接续既有 VM 链数据；证据已记录部署地址、TX 和区块，未破坏既有链目录。
- 多角色流程仍依赖 `crates/intergration_test` 的测试二进制长期运行；`run-e2e.sh` 已能编排 smoke，但还不是生产 daemon（守护进程）管理。
- VM 未安装 shellcheck，脚本已通过 `bash -n`，后续可在 CI（Continuous Integration，持续集成）或镜像中补齐 shellcheck。
