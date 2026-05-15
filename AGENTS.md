# 项目协作备忘

## 基本约定

- 涉及中文内容时使用 UTF-8（8 位统一码转换格式）等 Unicode（统一码）安全方式读取和写入文件。
- 英文专有名词或缩写第一次出现时标注中文释义，例如 Proxy（代理）、Node（管理员节点）、User（用户）。
- 本仓库是公开展示版，只保存可公开的源码、示例、脚本、Markdown（轻量标记语言）文档和脱敏证据摘要。

## 项目定位

本项目是基于 Rust（系统级编程语言）和 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）的分布式身份监管工程原型。核心目标是在保护正常用户匿名性的同时，为异常行为提供可审计、可追责的 Verify/Open（验证/揭示）流程。

当前公开仓库保留：

- `crates/`：Rust workspace（工作区）主线代码。
- `contracts/`：FISCO BCOS Solidity（智能合约编程语言）合约。
- `chain-apps/`：Java SDK（Software Development Kit，软件开发工具包）合约调用层。
- `apps/audit-console/`：只读 Web（网页）/API（Application Programming Interface，应用程序接口）审计控制台。
- `scripts/`：本地运行、FISCO BCOS 运维和证据刷新脚本。
- `examples/`：脱敏示例输入和审计事件样例。
- `docs/`：架构、运行、证据摘要、演示、计划和面试口径文档。

公开仓库不包含：

- 真实证书、私钥、账户文件、wallet（钱包）、keystore（密钥库）和 `conf/config.toml`。
- 内部原始压缩包、第三方测试原件、PDF（Portable Document Format，便携式文档格式）资料、docx（Word 文档）资料和 PPT（PowerPoint 演示文稿）资料。
- 运行大日志、runtime-state（运行时状态）、runtime-logs（运行日志目录）和未脱敏身份输入。

## 运行入口

- 项目总览：[README.md](README.md)
- 架构说明：[docs/architecture.md](docs/architecture.md)
- 运行说明：[docs/operations/README.md](docs/operations/README.md)
- 审计控制台：[apps/audit-console/README.md](apps/audit-console/README.md)
- 演示脚本：[docs/demo/audit-console-demo.md](docs/demo/audit-console-demo.md)
- 面试讲解：[docs/interview/project-walkthrough.md](docs/interview/project-walkthrough.md)
- 简历口径：[docs/interview/resume-bullets.md](docs/interview/resume-bullets.md)

## 敏感边界

- 不提交真实链端配置、证书、私钥和账户材料。
- 不提交真实姓名、身份证号、手机号、机构业务流水或未脱敏原始输入。
- `.example`、脱敏 JSON（JavaScript Object Notation，数据交换格式）样例和只读证据摘要可以提交。
- 只读审计控制台不连接真实链端，不读取证书、私钥、wallet、keystore、`conf/config.toml` 或运行大日志。

## 构建提示

- 推荐在 Ubuntu（Linux 发行版）或 VM（Virtual Machine，虚拟机）中构建。
- 根目录构建命令：

```bash
cargo build --workspace
```

- 身份字段加密模块需要设置动态库路径：

```bash
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:$LD_LIBRARY_PATH"
```

## 后续优先级

1. 将多角色长流程整理为 daemon（守护进程）或 service（服务）管理方式。
2. 完善 local（本机）、VM 和 multi-host（多主机）配置分层。
3. 收紧 CI（Continuous Integration，持续集成）中的 Rust 和 Java SDK 检查。
4. 补齐自动化部署脚本和证书/账户轮换策略。
