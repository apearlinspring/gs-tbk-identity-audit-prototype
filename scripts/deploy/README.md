# 部署脚本

本目录保存展示环境部署辅助脚本。当前重点是只读审计控制台的同步发布：从本地 Git（分布式版本控制系统）提交打包，通过 scp（Secure Copy Protocol，安全复制协议）上传到服务器，再在服务器上替换 `/opt/gs-tbk-audit-console`、重启 systemd（Linux 系统服务管理器）服务并执行健康检查。

## 审计控制台同步

Windows PowerShell（微软命令行外壳）中先进入仓库根目录：

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
cd D:\Users\Administrator\PycharmProjects\gs-tbk-identity-audit-prototype
git status
git pull --ff-only
```

同步公网展示服务器：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy/deploy-audit-console.ps1 -Target public
```

同步 VM（Virtual Machine，虚拟机）内网展示服务器：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy/deploy-audit-console.ps1 -Target vm
```

脚本会执行：

- `git archive HEAD`：只打包当前已提交版本，不把未提交改动带到服务器。
- `scp` 上传压缩包和远端同步脚本。
- 远端用 `node apps/audit-console/server.mjs --check` 做预检查。
- 保留 `/opt/gs-tbk-audit-console.backup-<timestamp>` 备份。
- 替换 `/opt/gs-tbk-audit-console`，写入 `DEPLOYED_COMMIT`。
- 重启 `gstbk-audit-console` 服务。
- 请求 `http://127.0.0.1:4173/api/health` 并再次执行 `server.mjs --check`。
- 本地可访问时，检查页面是否包含“项目快照”，并确认没有旧展示文案。

## 目标预设

| 目标 | SSH（Secure Shell，安全外壳协议）目标 | 远端 owner（文件属主） | 展示地址 |
| --- | --- | --- | --- |
| `public` | `root@117.72.156.97` | `gstbk-console:gstbk-console` | `https://gstbk.403edr.cn/` |
| `vm` | `gstbk-vm` | `gstbk:gstbk` | `http://192.168.1.24/` |

公网服务器的 80/443 入口由宝塔自带 Nginx（Web 服务器）托管；`nginx.service` 显示 failed 不一定代表公网不可用，应以 `https://gstbk.403edr.cn/` 和宝塔 Nginx 配置检查为准。

## 自定义目标

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy/deploy-audit-console.ps1 `
  -Target custom `
  -SshTarget root@example.com `
  -RemoteOwner gstbk-console:gstbk-console `
  -RemoteRoot /opt/gs-tbk-audit-console `
  -ServiceName gstbk-audit-console `
  -Port 4173 `
  -Url https://example.com/
```

如果远端需要 sudo（以普通用户登录后提升权限），加：

```powershell
-UseSudo
```

如果只想验证本地打包和参数，不上传到服务器：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy/deploy-audit-console.ps1 -Target public -DryRun
```

默认要求本地工作树干净，避免误以为未提交修改已经上线。若确实只想部署已提交的 `HEAD`，可加 `-AllowDirty`。

## 回滚

每次部署会保留一个备份目录，例如：

```text
/opt/gs-tbk-audit-console.backup-20260515T120000Z
```

部署过程中如果远端预检查、服务重启或健康检查失败，脚本会自动回滚到上一版。若需要手动回滚，可在服务器上执行：

```bash
sudo systemctl stop gstbk-audit-console
sudo mv /opt/gs-tbk-audit-console /opt/gs-tbk-audit-console.failed-manual
sudo mv /opt/gs-tbk-audit-console.backup-<timestamp> /opt/gs-tbk-audit-console
sudo chown -R gstbk:gstbk /opt/gs-tbk-audit-console
sudo systemctl start gstbk-audit-console
```

公网服务器的属主是 `gstbk-console:gstbk-console`，手动回滚时需要把 `chown` 的属主替换成公网对应值。
