# 示例说明

`examples/` 提供身份字段输入和审计事件样例，供本地复现与页面演示使用。

## 当前示例

- `id-info/user1.json` 与 `id-info/user2.json`：身份字段处理和 E2E 脚本使用的虚构 JSON 输入。
- `evidence/events.sample.json`：结构化 `events[]` 审计事件样例，覆盖审计查询、恶意揭示和失败场景。

身份字段使用合成数据。需要更多 User 输入时，按相同结构新增测试样例，或通过运行环境变量指定本地文件。
