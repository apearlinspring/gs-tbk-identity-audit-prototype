# GS-TBK 身份监管审计台

这个目录提供一个只读 Web（网页）/API（Application Programming Interface，应用程序接口）展示层，用于把仓库内已有 evidence JSON（JavaScript Object Notation，数据交换格式）摘要聚合成身份监管审计台。

当前实现不是纯静态 HTML（HyperText Markup Language，超文本标记语言）：前端资源是静态文件，后端由 Node（JavaScript 运行时）提供只读 API，并在每次请求时重新扫描本地 evidence JSON 摘要。刷新按钮只会重新加载服务器上已有的数据；如果刚跑完新的 VM（Virtual Machine，虚拟机）E2E（End-to-End，端到端）流程，需要先生成并安装新的 JSON 摘要。

## 安全边界

- 不连接真实 FISCO BCOS（金融区块链合作联盟开源区块链底层平台）。
- 不读取证书、私钥、wallet（钱包）、keystore（密钥库）、`conf/config.toml` 或运行大日志。
- 只读取 `examples/evidence/*.json` 和 `docs/evidence/*.json`，并且优先扫描 `examples/evidence/events.sample.json`。
- 展示内容来自已提交的摘要字段，包括 User（用户）、Contract（合约）、TX（Transaction，交易）、区块、Verify/Open（验证/揭示）、揭示字段和失败场景口径。

## 启动

需要 Node（JavaScript 运行时）18 或更新版本。

```bash
cd apps/audit-console
npm start
```

默认监听：

```text
http://127.0.0.1:4173
```

也可以显式指定端口：

```bash
node apps/audit-console/server.mjs --port 4180
```

Windows PowerShell（微软命令行外壳）建议使用 UTF-8（8 位统一码转换格式）输出：

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
node apps/audit-console/server.mjs --port 4180
```

## API

```text
GET /api/health
GET /api/evidence
```

`/api/evidence` 返回聚合后的只读模型：

- `sources`：读取到的 JSON 摘要路径、类型、SHA-256（安全哈希算法 256 位）和记录数量。
- `users`、`contracts`、`transactions`：用户、合约地址、TX 哈希和区块高度。
- `query_results`：`select`、`history@block`、`history@previous-block` 等查询判读。
- `verify_open`：Node（管理员节点）日志摘要中的 Verify/Open 状态。
- `reveal_fields`：结构化事件里的揭示字段。
- `failure_scenarios`：结构化失败场景口径。
- `events`：`events[]` 样例或后续结构化事件摘要。

## 最小验证

不启动 Web 服务也可以验证读取边界和 JSON 结构：

```bash
node apps/audit-console/server.mjs --check
```

期望输出中 `ok` 为 `true`，且 `sources` 只包含：

```text
examples/evidence/*.json
docs/evidence/*.json
```

这个检查不会读取真实链配置、证书、私钥、wallet、keystore、`conf/config.toml` 或运行大日志。

## VM 演示数据刷新

在 VM 上完成一次 `scripts/run-local/run-e2e.sh` 后，可以用 Manifest（运行清单）刷新控制台证据：

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --restart-service
```

该脚本会：

- 调用 `run-audit-query-demo.sh` 生成链上只读查询 JSON 摘要。
- 调用 `run-malicious-open-demo.sh` 生成 Verify/Open（验证/揭示）JSON 摘要。
- 将结果安装为 `docs/evidence/console-current-audit-query.json` 和 `docs/evidence/console-current-malicious-open.json`。
- 运行 `node apps/audit-console/server.mjs --check` 验证控制台仍能读取数据。
- 如果传入 `--restart-service`，重启 `gstbk-audit-console` systemd（Linux 系统服务管理器）服务。

`console-current-*.json` 和对应 Markdown（轻量标记语言）摘要已被 `.gitignore` 忽略，适合作为 VM 或公网演示站的当前数据。若某次运行需要沉淀为正式证据，应另存为带时间戳的 `docs/evidence/*-live-vm-*.json` / `.md` 文件后再提交。

如果只想离线演示命令和页面聚合能力，不连接 FISCO BCOS，可以加 `--dry-run-audit`：

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --dry-run-audit \
  --no-check
```

## 部署同步

从本地 Windows（微软操作系统）同步展示代码到服务器时，使用根目录脚本：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy/deploy-audit-console.ps1 -Target public
powershell -ExecutionPolicy Bypass -File scripts/deploy/deploy-audit-console.ps1 -Target vm
```

该脚本会打包当前 Git（分布式版本控制系统）提交，上传到服务器，保留上一版备份，重启 `gstbk-audit-console` 服务，并检查 `/api/health`。完整说明见 [scripts/deploy/README.md](../../scripts/deploy/README.md)。
