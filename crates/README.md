# 主线代码说明

`crates/` 是当前项目的 Rust（系统级编程语言）workspace（工作区）主线代码目录，已经升级到原 `gs_tbk_version2_9` 快照，并补入身份字段处理模块。

## 核心协议模块

- `class_group`：类群、CL 同态加密（Castagnos-Laguillaumie 同态加密）、同态运算和证明工具。
- `gs_tbk_scheme`：GS-TBK（Group Signatures with Time-bound Keys，带时间绑定密钥的群签名方案）公共参数、消息类型、时间树和类群生成辅助逻辑。

## 系统角色模块

- `proxy`：Proxy（代理）角色，维护代理地址、时间树、门限参数、群公钥、节点信息和用户信息。
- `node`：Node（管理员节点）角色，维护 DKG（Distributed Key Generation，分布式密钥生成）材料、密钥碎片、MtA（Multiplicative-to-Additive，乘法转加法分享协议）参数和注册/撤销状态。
- `user`：User（用户）角色，维护用户编号、代理地址、用户私钥、群公钥、撤销信息和签名逻辑。

## 集成测试与身份字段

- `intergration_test`：多节点集成测试入口，保留原项目拼写；内含 1 个 Proxy、4 个 Node、多个 User 的配置、脚本和运行日志。
- `cl_encrypt`：CL 加密 native library（原生库）的 Rust FFI（Foreign Function Interface，外部函数接口）封装，链接 `libencrypt.so`。
- `id_info_process`：身份字段处理模块，负责姓名和身份证号编码、CL 加密、ZKP（Zero-Knowledge Proof，零知识证明）生成、证明验证和密文解密。

## 维护注意

- 不要随手修改历史拼写，例如 `intergration_test`、`ThreasholdParam`、`threashold_param`；统一拼写应作为单独兼容重构处理。
- `intergration_test/src/**/logs` 与 `info/*.json` 是历史运行证据和测试状态，不应当当作生产配置。
- `id_info_process` 的密钥文件 `cl_keypair.json` 是生成材料，已归档到 `archive/generated/`，实际运行前应重新生成。
