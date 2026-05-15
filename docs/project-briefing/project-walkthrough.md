# 项目讲解包

本文用于项目复盘、项目讲解和项目定位校准。核心证据来自 2026-05-12 在真实 VM（Virtual Machine，虚拟机）上完成的 E2E（End-to-End，端到端）生产化 smoke（冒烟验证）验收，以及 2026-05-13 生成的审计查询和恶意揭示摘要：

- [E2E 验收报告](../evidence/e2e-report-20260512T153825Z.md)
- [链上审计查询复核](../evidence/audit-query-live-vm-20260512T153825Z.md)
- [恶意用户 Verify/Open 摘要](../evidence/malicious-open-live-vm-20260512T200205Z.md)
- [运行证据摘要](../evidence/runtime-summary.md)
- [失败场景库](../evidence/failure-scenarios.md)
- [第三方测试记录证据索引](third-party-test-evidence.md)

其中第三方测试记录用于证明 2024-10 早期项目在 5 台云服务器和 1 台本地服务器环境中完成过功能测试用例验证；2026-05 的真实 VM 复现证据用于证明当前仓库已经整理成可运行、可审计、可演示的工程原型。两类证据可以互相补强，但讲解时要分开讲，避免把历史第三方测试直接等同于当前仓库的完整生产验收。

一句话定位：这是一个基于 Rust（系统级编程语言）和 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）的分布式身份监管工程原型，用多管理员节点联合计算替代传统 PKI（Public Key Infrastructure，公钥基础设施）里的单一可信中心，并把身份密文、签名和审计证据登记到链上。

## 项目展示入口

如果技术评审允许看演示，优先从只读 Web（网页）/API（Application Programming Interface，应用程序接口）审计控制台切入，而不是先翻日志：

```bash
cd apps/audit-console
npm run check
npm start
```

默认访问 `http://127.0.0.1:4173`。讲解顺序建议是：先说明控制台只读取仓库内 `examples/evidence/*.json` 和 `docs/evidence/*.json` 等 JSON（JavaScript Object Notation，数据交换格式）摘要，不连接真实链端；再展示 `/api/evidence` 聚合出的 User（用户）、Contract（合约）、TX（Transaction，交易）、区块、查询判读、Verify/Open（验证/揭示）、揭示字段和失败场景；最后再回到 Rust 协议、FISCO BCOS 合约和 AI（Artificial Intelligence，人工智能）安全迁移口径。

这能让技术评审先看到“项目怎么被展示和审计”，再听底层实现，顺序更适合 AI 应用开发或 AI 安全方向。

## 2 分钟项目概述

可以按下面这版直接讲：

我做的是一个分布式身份监管工程原型，目标是在保护用户匿名性的同时，保留合规审计和恶意行为追责能力。传统方案里通常会有一个中心化 CA（Certificate Authority，证书颁发机构）或可信管理方，一旦它被攻破或作恶，身份和审计链路都会受影响。这个项目把监管权限拆给多个 Node（管理员节点），通过 GS-TBK（Group Signatures with Time-bound Keys，带时间绑定密钥的群签名方案）和门限协作流程，让用户平时可以用群签名保持匿名，但在签名异常或监管需要时，可以由管理员节点执行 Verify/Open 流程定位到责任用户。

系统里有 4 类角色。Proxy（代理）负责协调 KeyGen（联合密钥生成）、撤销和全局参数；Node 负责保存密钥份额、参与验证和揭示；User（用户）完成加入、签名和身份密文提交；FISCO BCOS 负责保存链上可审计证据。身份字段不直接明文上链，而是先做 CL（Castagnos-Laguillaumie，同态加密方案）加密，并生成 ZKP（Zero-Knowledge Proof，零知识证明），证明密文和承诺是按规则生成的。

最新证据不是本地假数据，而是在真实 VM 上跑通的 1 个 Proxy、4 个 Node、2 个 User 流程。E2E 运行前区块高度是 50，结束后是 54，正好产生 4 笔 TX（Transaction，交易）：两个用户各写入一笔签名和一笔身份密文。后续又做了链上审计查询：当前查询能查到，按登记区块能追溯，登记前一区块查不到。恶意揭示摘要里，user1 使用错误签名入口，4 个 Node 都查到链上签名、Verify 失败并触发 Open；user2 是正常对照，Verify 通过。

演示上我会先打开只读 Web/API 审计控制台，看审计查询、恶意揭示和失败场景的结构化摘要，再解释底层 Rust 协议和 FISCO BCOS 合约。边界也要讲清楚：它是生产化 smoke 通过的工程原型，不是完整可上线生产系统。早期 `20260512T153825Z` 摘要只证明 Verify/Open 状态闭环；最新 `20260512T200205Z` 复核已经从 Node stdout（标准输出）和 log4rs（Rust 日志框架）文件日志里捕获到 `user_id`、`user_name`、`address` 揭示字段。这里可以讲“异常签名被定位到协议用户和地址”，但不能夸大成完整生产审计平台。

## 5 分钟技术讲解结构

第 1 分钟讲展示入口和问题：先打开只读 Web/API 审计控制台，说明它聚合的是已提交的 JSON 摘要，不连接真实链端；然后切到问题本身，身份系统要同时满足隐私、监管和可审计。普通场景下用户不希望每次签名都暴露真实身份；监管场景下又不能让恶意行为完全匿名。因此项目选择“匿名使用 + 必要时可揭示”的群签名思路，并用多节点门限协作降低单点信任风险。

第 2 分钟讲架构：Proxy 协调全局流程，4 个 Node 持有不同密钥材料并参与 KeyGen、Verify/Open，User 负责 Join（用户加入）和 Sign（签名），FISCO BCOS 保存签名、身份密文和历史查询证据。链端调用由 Java SDK（Software Development Kit，软件开发工具包）wrapper（包装类）完成，Rust 侧通过脚本入口调用它们。

第 3 分钟讲身份链路：用户身份字段先进入 Rust 身份处理 CLI（Command Line Interface，命令行接口），生成 CL 密文、承诺和 ZKP。链上只登记 JSON（JavaScript Object Notation，数据交换格式）形式的密文与证明材料，不把真实身份字段作为明文提交。

第 4 分钟讲签名和审计：User 完成群签名后，把签名 JSON 写入 `Signature` 合约，把身份密文写入 `PersonalInfo` 合约。审计时可以做 `select` 查询当前记录，也可以按区块做 history（历史查询），证明某条记录在指定区块已经存在、在前一区块尚不存在。

第 5 分钟讲证据和边界：最新 E2E 报告显示真实 VM 上完成 1 Proxy + 4 Node + 2 User，区块 50 到 54，4 笔 TX 全部 `ret 0` 且 `select exists true`。恶意揭示摘要显示 user1 的错误签名被 4 个 Node 验证失败并触发 Open，user2 正常通过。最后强调这还是工程原型，服务管理、证书轮换、CI（Continuous Integration，持续集成）收紧和完整生产部署还在后续计划里。

## 架构关系

```text
User（用户）
  ├─ Join：向系统加入并获得签名能力
  ├─ Sign：生成群签名
  └─ 身份字段：生成 CL 密文和 ZKP

Proxy（代理）
  ├─ 协调 KeyGen
  ├─ 维护群公钥、时间树和撤销状态
  └─ 协调 Revoke（撤销）

Node（管理员节点）x 4
  ├─ 保存分布式密钥材料
  ├─ 查询链上 Signature 记录
  ├─ Verify：验证签名是否有效
  └─ Open：异常时执行揭示流程

FISCO BCOS（联盟链）
  ├─ Signature 合约：保存用户签名 JSON
  ├─ PersonalInfo 合约：保存身份密文和证明 JSON
  └─ history/select：支持链上审计追溯
```

讲解时可以把它说成四层：用户侧生成材料，Proxy 协调协议，Node 分布式监管，链端沉淀证据。

## 核心链路

1. 身份字段加密和证明

用户原始身份字段先经过 `id_info_process` 处理。核心产物包括 CL 密文、ZKP、commitment（承诺）和 `other_info` 等字段。CL 负责让真实身份不以明文形式上链；ZKP 负责证明密文和承诺的生成过程满足规则，避免用户提交任意伪造结构。

2. 多角色协议

Proxy 和 4 个 Node 完成 KeyGen，User 完成 Join 后获得群签名能力。用户签名时，外部验证者能验证“这是群内合法用户签的”，但正常情况下不直接知道具体是谁。这个匿名性和可追责性之间的平衡，是群签名方案的核心价值。

3. 签名和身份密文上链

User 通过 Rust 角色入口生成签名，再调用 Java SDK 包装脚本写入链端。`Signature` 合约保存签名记录，`PersonalInfo` 合约保存身份密文和证明记录。链上记录提供不可随意篡改的审计锚点，后续查询不依赖单机日志是否还存在。

4. 审计查询

审计查询分两类：`select` 证明当前主键下能查到记录；`history@block` 证明在登记区块能查到当时的历史记录；`history@previous-block` 返回 `ret -2`，证明登记前一区块还没有该记录。这个组合能说明“什么时候写入”和“写入后能否追溯”。

5. Verify/Open

Node 从链上查询签名记录后执行 Verify。正常用户 user2 的 Verify 通过；恶意演示用户 user1 通过 `sign_wrong` 入口生成异常签名，4 个 Node 均记录 Verify 失败并触发 Open，Open 状态完成。最新真实 VM 复核已经捕获 `user_id:1`、`user_name:e2e20260512T200205Z_user1` 和 `127.0.0.1:60001`，因此讲解中可以说“异常签名触发 Open 并定位到协议用户和地址”，同时说明这仍是 smoke 级摘要，不是生产审计平台。

## 真实证据如何支撑项目表述

| 可讲表述 | 最新证据 |
| --- | --- |
| 完成 1 Proxy + 4 Node + 2 User 多角色 E2E | `e2e-report-20260512T153825Z.md` 记录 Proxy 端口 `50000`，Node 端口 `50001` 到 `50004`，User 端口 `60001`、`60002`，运行成功耗时 411 秒 |
| 签名和身份密文都已写入链上 | 区块高度从 50 增至 54；user1/user2 各写入 `Signature` 和 `PersonalInfo`，共 4 笔 TX，全部 `ret 0`、`select exists true` |
| 支持链上审计查询 | 审计报告中 2 个 User、2 个合约的 `select` 均为 `exists true`，登记区块 history 均为 `ret 0`，登记前一区块均为 `ret -2` |
| 支持恶意签名触发揭示流程 | 恶意揭示摘要中 user1 为 `sign_wrong`，4 个 Node 均显示 `Signature` 查询 `exists true`、Verify 失败并触发 Open、Open 完成；最新 `20260512T200205Z` 摘要捕获 `user_id`、`user_name` 和地址 |
| 有明确工程边界 | 运行证据摘要说明当前是工程原型和生产化 smoke，不是 systemd（系统服务管理器）级 daemon（守护进程）部署，也没有提交真实证书、私钥或链端配置 |

最新 4 笔链上写入可以背这组数字：

| 用户 | 合约 | 区块 | TX 哈希 |
| --- | --- | --- | --- |
| `e2e20260512T153825Z_user1` | `Signature` | 51 | `0x6241dbee06f3de44c1f8090549e7e835ba8c7d7bf7c529251370e98da2396edb` |
| `e2e20260512T153825Z_user2` | `Signature` | 52 | `0xfceab5a2c4927e908499d4a517f6c5d1fe9c3f62d2bb3c6c9e3e81d19169ff23` |
| `e2e20260512T153825Z_user1` | `PersonalInfo` | 53 | `0xfc5613668bf381f3bd0d9b939688a909148ceddf612906c9f1a23d9ac6c6c907` |
| `e2e20260512T153825Z_user2` | `PersonalInfo` | 54 | `0x9b52c5c553b00196223b36ea70fb9b9c5d583ec1053d24e60ea2b87da4dcacd9` |

## 必须如实说明的边界

- 这是生产化 smoke 通过的工程原型，不是可上线生产系统。
- 多角色入口已经从历史测试入口整理到正式角色脚本，但服务管理仍是本地 supervisor（服务管理器）脚本，不是完整 systemd 生产部署。
- 真实证书、私钥、wallet（钱包）、keystore（密钥库）、`conf/config.toml` 和 runtime（运行时）状态没有提交到仓库。
- 最新真实 VM 恶意揭示摘要已经捕获 `user_id`、`user_name` 和地址字段，但它仍是 smoke 级日志摘要，不是带权限控制、长期留存和检索能力的生产审计平台。
- 只读审计控制台是 Web/API 展示入口，不是生产级审计平台；它不连接真实 FISCO BCOS 节点，不读取证书、私钥、wallet、keystore 或 `conf/config.toml`。
- 项目能支撑“可复现工程原型”“生产化 smoke 验证通过”“完成多角色链上闭环”等表述；不应表述为“已经生产上线”“完整商用身份监管平台”或“所有生产安全策略已落地”。
- AI 方向公开材料里不能写成“大模型训练算法”“Prompt Injection（提示词注入）完整防护系统”或“已上线生产级 AI 治理平台”；更准确的口径见 [project-positioning.md](project-positioning.md)。

## 深挖问答

**为什么要上链？**

上链不是为了把所有计算都搬到链上，而是为了给关键证据做不可随意篡改的登记和追溯。签名和身份密文写入合约后，可以用 `select` 查当前状态，也可以按区块查历史状态。这样技术评审问“怎么证明不是事后改日志”时，可以回答：本次证据里区块 50 到 54 的 4 笔 TX、登记区块 `ret 0`、前一区块 `ret -2` 形成了时间线。

**为什么先展示 Web/API 审计控制台？**

因为它把原本分散在 Markdown（轻量标记语言）报告、JSON 摘要和事件样例里的证据聚合成一个只读入口，技术评审能直观看到项目不是只停留在论文或命令行日志。这里要主动说明控制台只消费已提交摘要，不连接真实链端；它是演示层和审计视图，不是生产审计系统。

**为什么需要多节点？**

如果只有一个监管节点，它就是新的单点信任中心。多 Node 的设计把密钥材料和揭示能力拆开，单个节点不应独立决定全部监管结果。这个项目的验证拓扑是 4 个 Node，已经完成 KeyGen、链上查询、Verify 和 Open 状态闭环。

**恶意用户如何揭示？**

演示里 user1 使用 `sign_wrong` 入口生成异常签名，签名仍写入链上。Node 从 `Signature` 合约查询到记录后执行 Verify，发现失败后触发 Open。真实日志证明 4 个 Node 都经历了“查询存在、Verify 失败、Open 完成”，最新复核还捕获了 `user_id/user_name/address` 揭示字段。需要补充边界：这是面向 smoke 和项目讲解的摘要证据，还没有上升到生产级审计平台。

**CL 和 ZKP 分别负责什么？**

CL 负责把身份字段加密成链上可保存的密文，避免明文身份直接暴露。ZKP 负责证明密文、承诺等材料是按协议规则生成的，让链上或审计侧能相信材料结构，而不必看到身份明文。

**Java SDK 负责什么？**

Java SDK 负责和 FISCO BCOS 交互：调用 `Signature` 和 `PersonalInfo` 合约的 register（登记）、select（查询）和 history（历史查询）。Rust 侧负责协议和身份处理，Java SDK 侧负责链端落库和读取，两边通过脚本和 JSON 产物衔接。

**项目与 AI 安全方向怎么衔接？**

AI（Artificial Intelligence，人工智能）安全里也有“匿名使用、行为留痕、异常追责”的需求，比如智能体调用工具、模型服务访问敏感数据、自动化交易或内容发布。这个项目不是大模型安全算法本身，但它提供了一类身份与审计基础设施思路：正常行为保持最小暴露，异常行为有可验证证据链和可追责入口。

**如果面 AI 应用开发，怎么讲价值？**

重点讲系统集成和可展示交付：Rust 负责协议与身份处理，Java SDK 负责链端合约调用，审计控制台提供 Web/API 展示入口，最终能把多角色 E2E、链上交易、历史查询、恶意揭示和失败场景变成可演示的证据模型。AI 应用开发方向可以把它类比为智能体工具调用审计、模型服务敏感操作留痕和后台审计控制台。

**如果面 AI 安全，怎么讲价值？**

重点讲安全问题抽象：它不是训练模型，而是解决“谁在调用、证据在哪里、异常如何追责、监管权是否单点集中”。这可以迁移到智能体工具调用、模型服务高风险操作、数据访问留痕和联合微调参与方审计。边界也要同步说清：当前没有实现 Prompt Injection 防护算法，也没有训练大模型。

**技术评审问生产化程度，怎么答？**

可以答：我不会把它包装成完整生产系统。它现在是工程原型，已经做到了真实 VM 上的生产化 smoke：链端复用、配置隔离、脚本化启动、manifest 记录、4 笔真实 TX、审计查询和恶意揭示状态闭环。下一步要补的是长期 daemon、配置分层、证书轮换、CI 收紧和更完整的日志采集。

## 失败场景口径

如果技术评审继续问“失败了怎么定位”，可以结合 [失败场景库](../evidence/failure-scenarios.md) 回答：当前不是只跑 happy path（正常路径），也整理了常见故障的触发方式、预期失败点、分类和恢复建议。

| 场景 | 回答口径 |
| --- | --- |
| 缺合约地址 | doctor（健康检查）或 E2E 前置校验会提前失败，错误归类为合约地址配置缺失 |
| 缺证书 | Java SDK 链接链节点前会检查证书材料，不把真实证书提交到仓库 |
| 链不可达 | 先看端口和 Java SDK 区块查询是否失败，避免把链端网络问题误判成协议问题 |
| 端口占用 | `run-e2e.sh` 启动角色前检查 Proxy/Node/User 端口，失败时不继续拉起角色 |
| 错误身份字段 | 身份字段 CLI 在编码阶段失败，还没进入 CL 加密或 ZKP 验证 |
| 重复注册 | `Signature` 合约第二次同名登记返回业务失败码，可用 `select` 复核原记录仍存在 |

这部分可以总结为：工程原型已经具备故障定位和恢复口径，但还没有上升到生产级告警、自动恢复和安全运维体系。

## 项目描述

不夸大的通用项目描述：

基于 Rust + FISCO BCOS 的分布式身份监管工程原型：围绕群签名、身份字段 CL 加密和链上审计，搭建 1 Proxy + 4 Node + 2 User 的多角色验证环境，实现身份密文/ZKP 生成、签名与身份记录上链、链上历史查询、异常签名 Verify/Open 状态闭环，并在真实 Ubuntu（Linux 发行版）VM 上完成生产化 smoke 验证。

可选通用 bullet（项目符号）：

- 负责整理 Rust workspace（工作区）工程化结构和多角色运行入口，将 Proxy、Node、User 从历史 demo（演示工程）流程收口到可复现脚本，支持 runtime 配置隔离和 manifest 证据记录。
- 接入 FISCO BCOS 合约与 Java SDK 调用层，完成 `Signature` / `PersonalInfo` 的 register、select 和 history 查询；最新真实 VM E2E 中区块从 50 增至 54，产生 4 笔链上 TX 且均可查询。
- 纳入身份字段 CL 加密与 ZKP 处理链路，为 2 个脱敏用户样例生成独立身份密文和证明，并将密文材料写入 `PersonalInfo` 合约。
- 完成 1 Proxy + 4 Node + 2 User 的生产化 smoke：KeyGen、Join、Revoke、Sign、链上登记、Node 查询、Verify/Open 均形成摘要证据。
- 沉淀审计查询、恶意揭示、失败场景和只读 Web/API 审计控制台，明确工程原型边界，避免把 smoke 验证夸大为完整生产系统。

面向 AI 应用开发和 AI 安全方向的版本化项目表述见 [project-positioning.md](project-positioning.md)。
