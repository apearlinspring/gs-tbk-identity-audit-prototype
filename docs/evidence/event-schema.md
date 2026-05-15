# evidence event schema（证据事件模式）

本文定义审计证据的 `events[]` 结构化事件格式，用于把链上审计查询、恶意用户揭示和失败场景统一成后续 Web（网页）/API（Application Programming Interface，应用程序接口）展示、AI（Artificial Intelligence，人工智能）安全审计材料和演示报告都能复用的机器可读层。

该格式是现有 JSON（JavaScript Object Notation，数据交换格式）摘要的旁路聚合层，不替换、不重命名、不删除 `run-audit-query-demo.sh` 和 `run-malicious-open-demo.sh` 已经输出的字段。生产事件生成器应读取现有摘要，生成独立的 `events[]` 文件，并通过 `evidence_refs` 回指原始 Markdown（轻量标记语言）摘要、JSON 摘要、manifest（运行清单）、查询输出和日志 SHA-256（安全哈希算法 256 位）。

## 顶层结构

```json
{
  "schema_version": "gstbk.evidence.events.v1",
  "generated_at": "2026-05-13T00:00:00Z",
  "source_summaries": [],
  "events": []
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `schema_version` | string | 是 | 当前固定为 `gstbk.evidence.events.v1`。 |
| `generated_at` | string | 是 | 事件文件生成时间，使用 UTC（Coordinated Universal Time，协调世界时）ISO-8601 格式。 |
| `source_summaries` | array | 建议 | 输入摘要索引，用于声明事件由哪些现有摘要派生。 |
| `events` | array | 是 | 结构化事件列表。 |

`source_summaries[]` 建议包含：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `source_type` | string | 例如 `audit_query_summary`、`malicious_open_summary`、`failure_scenarios_doc`。 |
| `path` | string | 仓库相对路径或运行环境中的只读路径。 |
| `sha256` | string/null | 已知 SHA-256；无法固定时可为 `null`。 |
| `preserved_fields` | array | 对现有 JSON 摘要，列出保持原样的顶层字段，便于兼容性检查。 |

现有 JSON 摘要的兼容字段至少包括：

```text
generated_at, manifest, output_dir, success, users, contract_addresses,
tx_hashes, block_numbers, query_results, verify_open_status, log_sha256, notes
```

## 事件必填字段

每个 `events[]` 元素至少包含以下字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `event_id` | string | 全局唯一事件编号，建议由事件类型、时间、目标和关键 TX（Transaction，交易）哈希派生。 |
| `event_type` | string | 枚举：`audit_query`、`malicious_open`、`failure_scenario`。 |
| `timestamp` | string | 事件观察或摘要生成时间，使用 UTC ISO-8601 格式。 |
| `source` | object | 事件来源，例如脚本名、摘要路径、manifest 路径和 SHA-256。 |
| `actor` | object | 执行动作或产生判读的主体，例如 Auditor（审计者）、Node（管理员节点）、Operator（运维人员）。 |
| `target` | object | 被审计、被揭示或失败命中的对象，例如 User（用户）、合约记录、配置项。 |
| `chain` | object | 链端证据。即使失败尚未写链，也保留该对象并说明链端诊断上下文。 |
| `status` | string | 事件状态，按事件类型取值。 |
| `evidence_refs` | array | 证据引用列表，记录路径、SHA-256、类型和简述。 |
| `risk_level` | string | 枚举：`info`、`low`、`medium`、`high`、`critical`。 |
| `summary` | string | 面向 Web/API/AI 展示的一句话摘要，不内嵌大日志或真实秘密。 |

## 通用对象约定

`source` 建议包含：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `kind` | string | `script_summary`、`manual_doc`、`fixture` 等。 |
| `name` | string | 脚本名或文档名。 |
| `summary_path` | string/null | 摘要文件路径。 |
| `summary_sha256` | string/null | 摘要文件 SHA-256。 |
| `manifest_path` | string/null | E2E（End-to-End，端到端）manifest 路径。 |
| `manifest_sha256` | string/null | manifest SHA-256。 |

`actor` 建议包含：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `role` | string | `auditor`、`node_committee`、`operator`、`script` 等。 |
| `id` | string | 稳定主体编号。 |
| `name` | string | 可读名称。 |
| `nodes` | array | 多 Node 协同场景可列出 `node1` 到 `node4`。 |

`target` 建议包含：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `kind` | string | `chain_record`、`user`、`configuration`、`runtime` 等。 |
| `manifest_user` | string/null | manifest 中的用户键，例如 `user1`。 |
| `user_id` | string/null | 协议用户编号；未知时为 `null`。 |
| `user_name` | string/null | 脱敏或测试用户名。 |
| `contract_name` | string/null | `Signature`、`PersonalInfo` 或 `null`。 |
| `operation` | string/null | `select_history`、`verify_open`、`doctor_check` 等。 |
| `failure_code` | string/null | 失败场景分类，例如 `CONFIG_CONTRACT_ADDRESS_MISSING`。 |
| `reveal_fields` | object/null | 恶意揭示事件捕获的 `user_id`、`user_name` 和地址等字段。 |

`chain` 建议包含：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `platform` | string | 当前为 `FISCO BCOS`（金融区块链合作联盟开源区块链底层平台）。 |
| `group` | string/null | 例如 `group0`。 |
| `contract_key` | string/null | `signature`、`personal_info` 或 `null`。 |
| `contract_name` | string/null | 合约名。 |
| `contract_address` | string/null | 合约地址；失败前置诊断可为 `null`。 |
| `tx_hash` | string/null | 单记录事件的 TX 哈希。 |
| `block_number` | string/null | 单记录事件的区块高度。 |
| `queries` | array | 审计查询事件的 `select`、`history@block`、`history@previous-block` 判读。 |
| `records` | array | 多合约事件可列出 `Signature` 与 `PersonalInfo` 记录。 |
| `diagnostic` | string/null | 失败场景中对链端状态的简述。 |

`evidence_refs[]` 建议包含：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `kind` | string | `json_summary`、`markdown_summary`、`manifest`、`query_output`、`role_log`、`doc` 等。 |
| `path` | string | 仓库相对路径或运行环境只读路径。 |
| `sha256` | string/null | 文件 SHA-256；无法固定时为 `null`。 |
| `description` | string | 该证据如何支撑事件。 |

## 事件类型

### `audit_query`

审计查询事件记录某个 User/Contract（合约）在链上的当前查询和历史查询判读，目标是解释“记录在哪笔 TX、哪个区块写入，以及登记前后是否可追溯”。

建议状态：

| `status` | 说明 |
| --- | --- |
| `confirmed` | 当前查询和登记区块历史查询均可复核。 |
| `partial` | 只有部分查询成功，仍保留失败查询的证据引用。 |
| `failed` | 查询命令失败或输出不可判读。 |
| `dry_run` | 只生成命令计划，不连接真实链。 |

### `malicious_open`

恶意揭示事件记录异常签名 Verify（验证）失败后触发 Open（揭示），并把被揭示用户、Node 日志、链上签名和身份密文旁证合并为一个事件。

建议状态：

| `status` | 说明 |
| --- | --- |
| `open_completed` | Verify 失败且 Open 已完成。 |
| `open_started` | 已进入 Open，但未捕获完成状态。 |
| `verify_passed_control` | 正常对照用户 Verify 通过，未触发本用户 Open。 |
| `inconclusive` | 日志不足，无法判定。 |

### `failure_scenario`

失败场景事件记录预期失败的触发命令、错误分类、失败点和恢复建议。它可以没有 TX 或区块，但仍应保留 `chain` 对象说明诊断发生在链端配置、连接或业务调用边界。

建议状态：

| `status` | 说明 |
| --- | --- |
| `expected_failure` | 失败按预期发生，能被分类和解释。 |
| `recovered` | 已记录恢复动作并复核通过。 |
| `blocked` | 失败阻塞后续流程，仍待处理。 |
| `inconclusive` | 失败输出不足，无法分类。 |

## 安全边界

- 不在事件文件中内嵌真实证书、私钥、账户、wallet（钱包）、keystore（密钥库）、`conf/config.toml`、runtime-state（运行时状态）或大日志。
- 身份字段只保留测试用户名、协议用户编号、地址揭示字段、TX 哈希、区块号和 SHA-256；真实身份输入或密钥材料必须继续留在被忽略路径或安全运行环境。
- `events[]` 可以引用 `/tmp` 运行路径，但提交到仓库的样例只能包含脱敏 fixture（夹具）或已有证据文档路径。
- 后续如果从现有 JSON 摘要自动生成事件，生成器应把原摘要作为只读输入，不改动原摘要顶层字段。

## 样例与自测

样例文件见 `examples/evidence/events.sample.json`，覆盖 `audit_query`、`malicious_open` 和 `failure_scenario` 三类事件。

轻量自测不连接真实链，只解析样例并校验关键字段：

```bash
bash scripts/evidence/self-test-event-schema.sh
```
