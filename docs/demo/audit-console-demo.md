# GS-TBK 身份监管审计台演示 Runbook

本文用于现场演示 GS-TBK（Group Signatures with Time-bound Keys，带时间绑定密钥的群签名方案）身份监管审计台。演示目标是让观众先看到“身份登记、链上查询、验证、揭示”的可视化证据，再回到 Rust（系统级编程语言）、FISCO BCOS（金融区块链合作联盟开源区块链底层平台）和多节点协议实现。

## 演示入口

| 场景 | 地址 | 说明 |
| --- | --- | --- |
| 公网展示 | `https://gstbk.403edr.cn/` | 部署在公网服务器，适合远程展示或对外展示后给技术评审预览。 |
| VM（Virtual Machine，虚拟机）内网展示 | `http://192.168.1.24/` | 部署在 `gstbk-vm`，适合本机或同一局域网内演示。 |
| VM 域名展示 | `http://vm-gstbk.403edr.cn/` | 已解析到 `192.168.1.24`，适合作为 VM 内网演示入口。 |

注意：DNS（Domain Name System，域名系统）大小写不敏感，`GSTBK.403edr.cn` 和 `gstbk.403edr.cn` 是同一个域名。当前稳定口径应为：

- 公网展示：`gstbk.403edr.cn -> 117.72.156.97`。
- VM 内网展示：`vm-gstbk.403edr.cn -> 192.168.1.24`。

如果同一域名同时存在 `117.72.156.97` 和 `192.168.1.24` 两条 A（Address，地址）记录，浏览器可能随机命中公网服务器或 VM，应先删除多余记录。

本机临时强制命中 VM 可用：

```bash
curl --resolve vm-gstbk.403edr.cn:80:192.168.1.24 http://vm-gstbk.403edr.cn/
```

Windows（微软操作系统）浏览器要临时强制命中 VM，可以在管理员权限下修改 `C:\Windows\System32\drivers\etc\hosts`：

```text
192.168.1.24 vm-gstbk.403edr.cn
```

演示结束后记得移除这条 hosts（主机名映射）记录，避免影响公网域名访问。

## 当前 VM 部署状态

VM 上的控制台部署为 systemd（Linux 系统服务管理器）服务：

| 项目 | 值 |
| --- | --- |
| 应用目录 | `/opt/gs-tbk-audit-console` |
| 服务名 | `gstbk-audit-console` |
| Node.js（JavaScript 运行时） | `/usr/local/bin/node` |
| 应用监听 | `127.0.0.1:4173` |
| Nginx（Web 服务器）监听 | `0.0.0.0:80` |
| 反代配置 | `/etc/nginx/sites-available/gstbk-audit-console` |

检查命令：

```bash
ssh gstbk-vm 'systemctl is-active gstbk-audit-console nginx'
ssh gstbk-vm 'curl -sS http://127.0.0.1:4173/api/health'
curl http://192.168.1.24/api/health
```

## 同步展示代码

每次公开仓库更新后，可以从 Windows（微软操作系统）本地工作站把最新提交同步到展示服务器：

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
cd D:\Users\Administrator\PycharmProjects\gs-tbk-identity-audit-prototype
git status
git pull --ff-only

powershell -ExecutionPolicy Bypass -File scripts/deploy/deploy-audit-console.ps1 -Target public
powershell -ExecutionPolicy Bypass -File scripts/deploy/deploy-audit-console.ps1 -Target vm
```

脚本流程是：本地 `git archive HEAD` 打包、scp（Secure Copy Protocol，安全复制协议）上传、远端 `server.mjs --check` 预检查、备份旧 `/opt/gs-tbk-audit-console`、替换新版本、重启 `gstbk-audit-console` 服务、检查 `/api/health`。完整参数和回滚方式见 [部署脚本](../../scripts/deploy/README.md)。

公网服务器的 HTTPS（HyperText Transfer Protocol Secure，安全超文本传输协议）入口由宝塔 Nginx（Web 服务器）托管；如果系统自带 `nginx.service` 显示 failed，但 `https://gstbk.403edr.cn/` 能访问且宝塔 Nginx 配置检查通过，可以按宝塔入口判断公网展示状态。

## 1 分钟演示顺序

1. 打开 `http://vm-gstbk.403edr.cn/`、`http://192.168.1.24/` 或 `https://gstbk.403edr.cn/`。
2. 指向顶部指标：证据批次、结构化事件、用户、合约、交易、区块、查询、验证/揭示。
3. 看左侧“项目快照”：说明本轮复核拓扑是 1 Proxy、4 Node、2 User，证据覆盖签名、身份密文、交易、区块和揭示字段。
4. 展示“结构化事件”：覆盖审计查询、异常揭示和失败场景。
5. 展示“交易与区块”：说明签名和身份密文分别写入 `Signature` 与 `PersonalInfo` 合约。
6. 展示“验证与揭示”：说明异常签名触发 Verify/Open（验证/揭示），正常用户作为对照。

一句话讲法：

> 这个页面不是日志截图，而是从 E2E（End-to-End，端到端）运行后的 JSON（JavaScript Object Notation，数据交换格式）证据中聚合出来的审计视图。它把用户、合约、交易、区块、查询判读和异常揭示放到一个页面里讲清楚，适合先展示结果，再回到 Rust、FISCO BCOS 和多节点协议实现。

## 5 分钟演示顺序

第一分钟：讲问题。

身份系统需要同时满足匿名性和可追责性。用户正常签名时不暴露真实身份，但出现异常签名或监管需求时，管理员节点应能协作揭示责任用户。

第二分钟：讲架构。

系统包含 User（用户）、Proxy（代理）、Node（管理员节点）和 FISCO BCOS。User 生成签名和身份密文；Proxy 协调全局参数、KeyGen（联合密钥生成）和撤销；4 个 Node 参与 Verify/Open；FISCO BCOS 负责保存签名、身份密文和链上审计证据。

第三分钟：讲链上证据。

控制台里的交易和区块来自两类合约：

- `Signature`：保存用户群签名 JSON。
- `PersonalInfo`：保存身份密文、承诺和证明材料。

可以用 `select` 查询当前记录，也可以按区块做 history（历史查询），证明某条记录在登记区块已存在、登记前一区块还不存在。

第四分钟：讲异常揭示。

恶意演示用户使用错误签名入口，Node 从链上查到签名后 Verify 失败，随后触发 Open。最新证据摘要可以展示 `user_id`、`user_name` 和地址揭示字段。正常用户 Verify 通过，用来说明不是所有用户都会被揭示。

第五分钟：讲边界。

这个控制台是只读展示层，不是生产级审计平台。它不读取真实证书、私钥、wallet（钱包）、keystore（密钥库）、`conf/config.toml` 或运行大日志。它的价值是把底层 E2E 证据变成可浏览、可筛选、可讲解的展示入口。

## 刷新 VM 演示数据

如果只是展示当前快照，不需要刷新。若 VM 上刚跑完新的 E2E 流程，先拿到 `run-e2e.sh` 输出的 manifest（运行清单）路径，再刷新控制台证据。

在完整源码目录中执行：

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=0x6546c3571f17858ea45575e7c6457dad03e53dbb
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=0xcceef68c9b4811b32c75df284a1396c7c5509561

bash scripts/evidence/refresh-audit-console-evidence.sh \
  --manifest /tmp/gstbk-e2e-vm-smoke/runtime-logs/<timestamp>/manifest.json \
  --console-root /opt/gs-tbk-audit-console \
  --restart-service gstbk-audit-console
```

如果只想更新恶意揭示摘要、不重新连链查询审计历史，可加：

```bash
--skip-audit-query
```

如果只想离线演示命令计划，不连接 FISCO BCOS，可加：

```bash
--dry-run-audit
```

刷新后验证：

```bash
curl http://192.168.1.24/api/health
ssh gstbk-vm 'systemctl is-active gstbk-audit-console nginx'
```

## 讲解边界

演示时建议主动说清楚：

- 当前控制台是“只读展示层”，不是链节点管理后台。
- 页面刷新只会重新读取服务器本地 JSON 摘要，不会自动启动 E2E。
- 真正的 E2E 仍应在 SSH（Secure Shell，安全外壳协议）终端运行，避免把执行权限暴露到公网。
- 公网展示站适合远程预览；VM 展示站适合本地网络或答辩现场演示。
- 如果要把某次运行固化为长期证据，应把 `console-current-*` 另存为带时间戳的 `docs/evidence/*-live-vm-*.json` / `.md`。

## 常见问题

### 打开域名时看到的不是 VM 页面

先查 DNS：

```powershell
Resolve-DnsName gstbk.403edr.cn -Type A
Resolve-DnsName vm-gstbk.403edr.cn -Type A
```

如果公网域名出现 `192.168.1.24`，或 VM 域名出现 `117.72.156.97`，说明 DNS 记录混用了。演示 VM 时可先改用 `http://192.168.1.24/`，或临时写 hosts。

### 页面能打开，但数据不是最新

控制台不会自己跑 E2E。先确认新的 manifest 路径，再执行 `refresh-audit-console-evidence.sh`。

### 健康检查失败

按顺序检查：

```bash
ssh gstbk-vm 'systemctl status gstbk-audit-console --no-pager'
ssh gstbk-vm 'journalctl -u gstbk-audit-console -n 80 --no-pager'
ssh gstbk-vm 'nginx -t'
ssh gstbk-vm 'curl http://127.0.0.1:4173/api/health'
```
