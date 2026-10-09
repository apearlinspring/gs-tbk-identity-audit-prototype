# Rust 模块

`crates/` 是项目的 Rust 工作区，基于原 `gs_tbk_version2_9` 快照，并加入身份字段处理模块。

## 协议与角色

- `class_group`：类群、CL 同态加密、同态运算和证明工具。
- `gs_tbk_scheme`：公共参数、消息类型、时间树和类群生成辅助逻辑。
- `proxy`：维护时间树、门限参数、群公钥及节点和用户信息，协调协议阶段。
- `node`：维护 DKG 材料、密钥份额、MtA 参数及注册和撤销状态。
- `user`：维护成员密钥、群公钥、撤销信息，生成群签名。

## 运行入口与身份字段

- `intergration_test`：包含正式的 `gstbk-proxy`、`gstbk-node`、`gstbk-user` 入口和多角色集成测试；目录名保留历史拼写。
- `cl_encrypt`：CL 加密原生库的 Rust FFI 封装，链接 `libencrypt.so`。
- `id_info_process`：姓名和身份证号编码、CL 加密、证明生成与验证；也提供逆编码和底层解密相关函数。

角色运行方式见[本地运行脚本](../scripts/run-local/README.md)。运行状态和生成的 `cl_keypair.json` 放在被忽略的运行目录中，配置说明见[配置与密钥管理](../docs/operations/secrets-and-config.md)。
