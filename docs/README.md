# 文档索引

本目录只保存公开展示版文档：架构、运行、证据摘要、演示脚本、计划和项目展示口径。不包含内部原始 PDF（Portable Document Format，便携式文档格式）、docx（Word 文档）、PPT（PowerPoint 演示文稿）、第三方测试原件、真实证书、私钥、wallet（钱包）、keystore（密钥库）或 `conf/config.toml`。

## 项目说明

- `architecture.md`：当前 Rust（系统级编程语言）、Java SDK（Software Development Kit，软件开发工具包）、FISCO BCOS（金融区块链合作联盟开源区块链底层平台）和合约之间的架构与数据流。
- `project-summary.md`：工程化整理记录，说明主线代码、身份字段模块、链端调用和证据材料的收口过程。
- `ai-security-bridge.md`：说明当前分布式身份监管项目如何自然衔接 AI（Artificial Intelligence，人工智能）安全方向。
- `ci.md`：CI（Continuous Integration，持续集成）基础检查范围和后续启用条件。

## 发布与复现

- `releases/README.md`：release（发布）与复现材料索引。
- `releases/v0.1-engineering-prototype.md`：v0.1 工程原型发布说明。
- `releases/v0.2-auditable-prototype.md`：v0.2 可审计工程原型发布说明。
- `releases/v0.3-demo-console.md`：v0.3 演示控制台发布说明。

## 运行与演示

- `operations/README.md`：Proxy（代理）、Node（管理员节点）、User（用户）和身份字段加密模块的运行入口。
- `operations/fisco-runbook.md`：FISCO BCOS 运维自动化 Runbook（运行手册）。
- `operations/secrets-and-config.md`：敏感材料与配置边界。
- `operations/service-supervision.md`：本地服务管理说明。
- `operations/vm-access.md`：VM（Virtual Machine，虚拟机）路径与复核命令摘要。
- `demo/README.md`：演示文档索引。
- `demo/audit-console-demo.md`：身份监管审计台现场演示脚本，覆盖项目快照、结构化事件、交易区块和验证揭示。
- `../apps/audit-console/README.md`：只读 Web（网页）/API（Application Programming Interface，应用程序接口）审计控制台说明。

## 测试证据

- `evidence/README.md`：证据材料说明和可信度边界。
- `evidence/runtime-summary.md`：运行证据摘要。
- `evidence/fisco-contracts-phase1.md`：FISCO BCOS 合约编译、部署和调用验证记录。
- `evidence/fisco-java-sdk-stage2.md`：Java SDK 调用层联调记录。
- `evidence/e2e-report-20260512T153825Z.md`：真实 VM 上正式 E2E（End-to-End，端到端）验收摘要。
- `evidence/audit-query-live-vm-20260512T153825Z.md`：链上审计查询复核。
- `evidence/malicious-open-live-vm-20260512T200205Z.md`：恶意用户 Verify/Open（验证/揭示）摘要。
- `evidence/event-schema.md`：结构化 `events[]` 事件格式。
- `evidence/failure-scenarios.md`：失败场景库。

## 项目讲解

- `project-briefing/project-walkthrough.md`：面向项目复盘和背诵的项目讲解包。
- `project-briefing/project-positioning.md`：面向对外展示的项目表述版本。
- `project-briefing/third-party-test-evidence.md`：第三方功能测试记录的公开口径索引；不包含测试原件。

## 计划文档

- `plans/README.md`：计划文档索引。
- `plans/project-optimization-plan.md`：当前项目优化执行计划。
- `plans/thesis-ai-security-finetuning-plan.md`：AI 安全微调毕设设计方案。
