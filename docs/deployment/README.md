# 部署入口

协议运行需要 Linux、Rust 原生依赖，以及已配置的 FISCO BCOS 链和 Java SDK。按以下文档准备：

- [运行说明](../operations/README.md)：构建、角色启动和 E2E。
- [FISCO 运维手册](../operations/fisco-runbook.md)：链端检查、SDK 配置、合约部署与复用。
- [运维脚本](../../scripts/fisco/README.md)：各脚本的参数。
- [config.toml.example](../../chain-apps/fisco-bcos-java-sdk/conf/config.toml.example)：Java SDK 配置模板。
- [.env.example](../../.env.example)：Rust 与链端环境变量模板。

运行目录、文件权限和密钥放置方式见 [配置说明](../operations/secrets-and-config.md)。
