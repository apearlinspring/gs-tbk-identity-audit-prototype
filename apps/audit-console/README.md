# GS-TBK 身份监管审计台

审计台把本地 JSON 证据摘要汇总成页面，展示用户、合约、交易、Verify/Open 结果和失败场景。Node.js 提供 API，前端使用静态 HTML、CSS 和 JavaScript。

每次请求都会扫描 `examples/evidence/*.json` 和 `docs/evidence/*.json`，优先加载 `examples/evidence/events.sample.json`。页面刷新按钮重新加载这些摘要，审计台本身不查询 FISCO BCOS。新一轮 E2E 完成后，需要先运行下面的刷新脚本。

## 启动

需要 Node.js 18 或更新版本，无需安装额外依赖。

```bash
cd apps/audit-console
npm start
```

默认地址为 `http://127.0.0.1:4173`。指定端口：

```bash
node apps/audit-console/server.mjs --port 4180
```

Windows PowerShell 中可设置 UTF-8 输出：

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
node apps/audit-console/server.mjs --port 4180
```

## API

```text
GET /api/health
GET /api/evidence
```

`/api/evidence` 返回以下字段：

- `sources`：摘要路径、类型、SHA-256 和记录数量。
- `users`、`contracts`、`transactions`：用户、合约地址、交易哈希和区块高度。
- `query_results`：`select`、`history@block`、`history@previous-block` 等查询结果。
- `verify_open`：Node 日志摘要中的 Verify/Open 状态。
- `reveal_fields`：结构化事件里的揭示字段。
- `failure_scenarios`：失败场景摘要。
- `events`：`events[]` 中的结构化事件摘要。

## 检查数据

无需启动服务即可检查聚合结果和 JSON 结构：

```bash
node apps/audit-console/server.mjs --check
```

成功时输出 `ok: true`，`sources` 列出从上述两个目录读取的摘要。

## 更新演示数据

在虚拟机上完成一次 `scripts/run-local/run-e2e.sh` 后，用该次运行的 manifest 更新审计台：

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --restart-service
```

脚本会执行链上只读查询，提取角色日志中的 Verify/Open 结果，将两份摘要写入 `docs/evidence/console-current-audit-query.json` 和 `docs/evidence/console-current-malicious-open.json`，然后运行 `--check`。传入 `--restart-service` 时，还会重启 `gstbk-audit-console` systemd 服务。

`console-current-*.json` 和对应 Markdown 已被 `.gitignore` 忽略，方便展示环境更新当前数据。运行配置和证据保存方式见[配置与密钥管理](../../docs/operations/secrets-and-config.md)。

离线演示可以用 `--dry-run-audit` 生成查询命令计划：

```bash
bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json \
  --dry-run-audit \
  --no-check
```
