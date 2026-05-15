# 项目结构整理说明

## 整理目标

本项目原本是“资料包 + 多个 demo（演示工程）快照 + 新增运行材料”的混合目录。整理后的目标是让它成为可复现工程原型：根目录只保留入口文件，主线代码进入 `crates/`，公开运行资料进入 `docs/`，链端合约、Java SDK（Software Development Kit，软件开发工具包）调用层和 E2E（End-to-End，端到端）证据形成闭环。公开展示版不包含内部原始压缩包、第三方测试原件、运行大日志或未脱敏输入。

## 第二轮整理结果

本轮根据新增文件完成了以下调整：

- 将原 `gs_tbk_version2_9_1/gs_tbk_version2_9` 升级为主线 Rust（系统级编程语言）workspace（工作区）代码。
- 将旧主线与参考材料从公开展示版中剥离，只保留当前 Rust（系统级编程语言）workspace（工作区）主线。
- 将 `id_info_process` 与 `cl_encrypt` 纳入 `crates/`，补齐身份字段编码、CL 同态加密（Castagnos-Laguillaumie 同态加密）、ZKP（Zero-Knowledge Proof，零知识证明）生成和验证链路。
- 将公开运行手册、安全边界和 VM（Virtual Machine，虚拟机）复核摘要收口到 `docs/operations/`。
- 将可公开的第三方测试口径整理到 `docs/interview/third-party-test-evidence.md`，不提交测试原件。
- 将疑似真实身份样例从根目录移走，另在 `examples/id_info/` 添加干净的虚构示例。

## 当前主线

当前主线模块如下：

- `crates/class_group`
- `crates/gs_tbk_scheme`
- `crates/proxy`
- `crates/node`
- `crates/user`
- `crates/intergration_test`
- `crates/cl_encrypt`
- `crates/id_info_process`

根目录 `Cargo.toml` 已更新为包含上述成员的 workspace 配置。

## 当前证据链

- 代码层：`intergration_test` 包含 1 个 Proxy（代理）、4 个 Node（管理员节点）和多个 User（用户）的测试入口、配置、脚本和日志。
- 部署层：运行手册记录 Ubuntu（Linux 发行版）、VM、FISCO BCOS 和多角色启动的公开复核方式。
- 测试层：第三方测试口径索引包含“用户身份隐私保护与揭露监管”“用户隐私数据上链监管”等测试项，但不提交测试原件。
- 字段处理层：`id_info_process` 对姓名、身份证号等字段进行编码、CL 同态加密、ZKP（Zero-Knowledge Proof，零知识证明）生成和验证。
- 链端层：`PersonalInfo` 与 `Signature` 合约已在 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）v3.6.0 VM（Virtual Machine，虚拟机）环境完成编译、部署、写入、查询和历史区块查询。
- 生产化 smoke（冒烟验证）层：2026-05-11 基线 `e2e-baseline-2026-05-11` 跑通 1 Proxy + 4 Node + 2 User，全流程覆盖 KeyGen（联合密钥生成）、Join（用户加入）、Revoke（撤销）、Sign（签名）、链上 register（登记）、Verify（验证）和 Open（揭示）。

## 当前可支撑结论

- 项目已从“资料包集合”收口为 Rust + FISCO BCOS + Java SDK + Solidity（智能合约编程语言）+ 运行脚本 + 证据文档的一体化工程原型。
- Rust 到链端 E2E 已完成生产化 smoke 验证：阶段 3.2 区块高度从 `30` 增至 `34`，`Signature` 与 `PersonalInfo` 均返回 `exists true`，4 个 Node 均完成 Verify/Open。
- 简历表述可聚焦“Rust + FISCO BCOS + CL 身份字段加密/ZKP + 多节点 E2E + 链上审计”，但应明确它是可复现工程原型，不是完整生产系统。

## 仍需补强

- 多角色运行仍复用 `crates/intergration_test` 的 `cargo test` 长运行入口；后续应沉淀为 daemon（守护进程）/service（服务）或容器化运行方式。
- local（本机）、VM、multi-host（多主机）配置仍会渲染到 legacy fixture（历史夹具）路径；后续应拆出独立配置目录，避免运行配置和测试夹具耦合。
- CI（Continuous Integration，持续集成）仍是保守骨架，Rust 和 Java SDK 步骤带有 `continue-on-error`；后续应清理历史 rustfmt 差异并收紧强门禁。
- 自动化部署仍不完整，链节点启停、合约部署、wrapper（包装类）生成、配置渲染和 E2E 复核还没有统一部署命令。
- 真实证书、账户、wallet（钱包）、keystore（密钥库）和 `conf/config.toml` 仍需放在 VM 或安全本地目录，后续应补充安全放置、权限和轮换说明。
- 公开仓库不提交生成日志、密钥和运行态 `info/*.json`；后续若需要长期保留样例，应拆成 `fixtures/`、`logs/`、`state/` 三类并完成脱敏。
- 历史拼写 `intergration_test`、`ThreasholdParam`、`threashold_param` 暂时保留；若统一拼写，应单独做兼容重构。
