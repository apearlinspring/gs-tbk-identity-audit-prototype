# 发布与复现材料

本目录保存面向 release（发布）、交接和复现的版本化说明。这里的材料用于帮助新人、技术评审或后续维护者快速判断项目当前完成度、最短复现路径、验收标准和非生产能力边界。

## 版本入口

- [v0.1 工程原型发布与复现说明](v0.1-engineering-prototype.md)：生产化 smoke（冒烟验证）通过的工程原型说明，包含环境版本、合约地址、复现路径、验收 checklist（检查清单）和项目讲解口径。
- [v0.2 可审计工程原型发布说明](v0.2-auditable-prototype.md)：在 v0.1 基础上补齐失败场景、审计查询、恶意揭示、真实 VM（Virtual Machine，虚拟机）证据、JSON（JavaScript Object Notation，数据交换格式）摘要和项目讲解包，定位为可复现、可审计、可项目讲解的工程原型。
- [v0.3 演示控制台发布说明](v0.3-demo-console.md)：在 v0.2 基础上把只读 Web（网页）/API（Application Programming Interface，应用程序接口）审计控制台、`events[]` event schema（事件模式）和 AI（Artificial Intelligence，人工智能）安全桥接纳入正式里程碑，定位为可展示、可审计、可项目讲解的工程原型。

## 使用边界

- 本目录只记录可提交的文档、命令入口和证据索引，不保存真实证书、私钥、账户文件、wallet（钱包）、keystore（密钥库）、`conf/config.toml` 或运行日志。
- 当前 `v0.1` / `v0.2` / `v0.3` 均定位为工程原型，不是完整生产系统。
