# 示例说明

`examples/` 存放仍有参考价值、但不一定纳入主工作区的示例材料。

## 当前示例

- `mta_cl_bls12381`：MtA（Multiplicative-to-Additive，乘法转加法分享协议）封装版 demo，基于 BLS12-381（Barreto-Lynn-Scott 12-381 椭圆曲线）和 CL 同态加密（Castagnos-Laguillaumie 同态加密）。
- `id_info`：身份字段处理的虚构 JSON（JavaScript Object Notation，数据交换格式）样例。
- `evidence`：结构化 `events[]` 审计事件 fixture（夹具），覆盖审计查询、恶意揭示和失败场景。

## 注意

`mta_cl_bls12381` 保留自己的 `Cargo.toml`（Rust 包管理配置）和依赖结构，不在根目录 workspace（工作区）中，避免旧依赖影响主线构建。身份字段真实数据不要放在根目录或示例目录中。
