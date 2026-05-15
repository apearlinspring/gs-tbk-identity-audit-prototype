param(
    [ValidateSet("public", "vm", "custom")]
    [string]$Target = "custom",

    [string]$SshTarget = "",
    [string]$RemoteOwner = "",
    [string]$RemoteRoot = "/opt/gs-tbk-audit-console",
    [string]$ServiceName = "gstbk-audit-console",
    [int]$Port = 4173,
    [string]$NodeBin = "",
    [string]$Url = "",

    [switch]$UseSudo,
    [switch]$AllowDirty,
    [switch]$KeepRemoteTarball,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Text-FromCodePoints {
    param([int[]]$CodePoints)
    return -join ($CodePoints | ForEach-Object { [char]$_ })
}

Require-Command git
Require-Command scp
Require-Command ssh

switch ($Target) {
    "public" {
        if (-not $SshTarget) { $SshTarget = "root@117.72.156.97" }
        if (-not $RemoteOwner) { $RemoteOwner = "gstbk-console:gstbk-console" }
        if (-not $Url) { $Url = "https://gstbk.403edr.cn/" }
    }
    "vm" {
        if (-not $SshTarget) { $SshTarget = "gstbk-vm" }
        if (-not $RemoteOwner) { $RemoteOwner = "gstbk:gstbk" }
        if (-not $Url) { $Url = "http://192.168.1.24/" }
        $UseSudo = $true
    }
    "custom" {
        if (-not $SshTarget) { throw "Set -SshTarget for custom deployment." }
        if (-not $RemoteOwner) { throw "Set -RemoteOwner for custom deployment." }
    }
}

$repoRoot = (& git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

if (-not $AllowDirty) {
    $dirty = (& git status --porcelain)
    if ($dirty) {
        throw "Working tree is not clean. Commit or stash changes, or pass -AllowDirty to deploy committed HEAD only."
    }
}

$commit = (& git rev-parse --short HEAD).Trim()
$archive = Join-Path $env:TEMP "gstbk-audit-console-$commit.tar.gz"
$remoteArchive = "/tmp/gstbk-audit-console-$commit.tar.gz"
$remoteScript = "/tmp/sync-gstbk-audit-console.sh"

if (Test-Path -LiteralPath $archive) {
    Remove-Item -LiteralPath $archive -Force
}

Write-Host "[local] archive HEAD $commit"
& git archive --format=tar.gz -o $archive HEAD
if ($LASTEXITCODE -ne 0) { throw "git archive failed" }

$payload = @'
#!/usr/bin/env bash
set -euo pipefail

commit="$1"
owner="$2"
repo="$3"
service="$4"
port="$5"
node_bin_arg="${6:-}"
keep_tarball="${7:-0}"

tarball="/tmp/gstbk-audit-console-${commit}.tar.gz"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
tmp="/tmp/gstbk-audit-console-sync-${stamp}"
backup="${repo}.backup-${stamp}"
failed="${repo}.failed-${stamp}"

node_bin="$node_bin_arg"
if [ -z "$node_bin" ]; then
  node_bin="$(command -v node || true)"
fi
if [ -z "$node_bin" ] && [ -x /usr/local/bin/node ]; then
  node_bin="/usr/local/bin/node"
fi
if [ -z "$node_bin" ]; then
  node_bin="/usr/bin/node"
fi

rollback() {
  rc=$?
  echo "[remote] deployment failed rc=${rc}"
  if [ -d "$backup" ]; then
    systemctl stop "$service" >/dev/null 2>&1 || true
    if [ -d "$repo" ]; then
      mv "$repo" "$failed"
    fi
    mv "$backup" "$repo"
    chown -R "$owner" "$repo"
    systemctl start "$service" >/dev/null 2>&1 || true
    echo "[remote] rolled back to previous deployment"
  fi
  exit "$rc"
}

trap rollback ERR

[ -f "$tarball" ]
rm -rf "$tmp"
mkdir -p "$tmp"
tar --warning=no-timestamp -xzf "$tarball" -C "$tmp"
printf "%s\n" "$commit" > "$tmp/DEPLOYED_COMMIT"

"$node_bin" "$tmp/apps/audit-console/server.mjs" --check >/tmp/gstbk-audit-console-precheck-${stamp}.json

if [ -d "$repo/docs/evidence" ]; then
  cp -a "$repo"/docs/evidence/console-current-* "$tmp/docs/evidence/" 2>/dev/null || true
fi

systemctl stop "$service"
if [ -d "$repo" ]; then
  mv "$repo" "$backup"
fi
mv "$tmp" "$repo"
chown -R "$owner" "$repo"
systemctl start "$service"
sleep 1

curl -fsS "http://127.0.0.1:${port}/api/health" >/tmp/gstbk-audit-console-health-${stamp}.json
"$node_bin" "$repo/apps/audit-console/server.mjs" --check >/tmp/gstbk-audit-console-livecheck-${stamp}.json

trap - ERR

if [ "$keep_tarball" != "1" ]; then
  rm -f "$tarball" /tmp/sync-gstbk-audit-console.sh
fi

echo "[remote] deployed_commit=$(cat "$repo/DEPLOYED_COMMIT")"
echo "[remote] service=$(systemctl is-active "$service")"
echo "[remote] backup=$backup"
echo "[remote] health=/tmp/gstbk-audit-console-health-${stamp}.json"
'@

$payloadPath = Join-Path $env:TEMP "sync-gstbk-audit-console.sh"
[System.IO.File]::WriteAllText($payloadPath, $payload, [System.Text.UTF8Encoding]::new($false))

Write-Host "[local] target=$SshTarget root=$RemoteRoot service=$ServiceName owner=$RemoteOwner"
if ($DryRun) {
    Write-Host "[local] dry run complete: archive=$archive payload=$payloadPath"
    return
}

Write-Host "[local] upload archive and remote payload"
& scp -q $archive "${SshTarget}:$remoteArchive"
if ($LASTEXITCODE -ne 0) { throw "scp archive failed" }
& scp -q $payloadPath "${SshTarget}:$remoteScript"
if ($LASTEXITCODE -ne 0) { throw "scp payload failed" }

$keep = if ($KeepRemoteTarball) { "1" } else { "0" }
$remoteCommand = "bash $remoteScript $commit '$RemoteOwner' '$RemoteRoot' '$ServiceName' $Port '$NodeBin' $keep"
if ($UseSudo) {
    $remoteCommand = "sudo -n $remoteCommand"
}

Write-Host "[local] run remote deployment"
& ssh -o BatchMode=yes $SshTarget $remoteCommand
if ($LASTEXITCODE -ne 0) { throw "remote deployment failed" }

if ($Url) {
    Write-Host "[local] verify public page $Url"
    try {
        $page = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 15
        $projectSnapshot = Text-FromCodePoints @(0x9879, 0x76EE, 0x5FEB, 0x7167)
        $oldNeedles = @(
            (Text-FromCodePoints @(0x6F14, 0x793A, 0x8BF4, 0x660E)),
            (Text-FromCodePoints @(0x9762, 0x8BD5)),
            (Text-FromCodePoints @(0x69, 0x6E, 0x74, 0x65, 0x72, 0x76, 0x69, 0x65, 0x77)),
            (Text-FromCodePoints @(0x7B80, 0x5386)),
            (Text-FromCodePoints @(0x6295, 0x9012))
        )
        $hasSnapshot = $page.Content.Contains($projectSnapshot)
        $hasOldWords = $false
        foreach ($needle in $oldNeedles) {
            if ($page.Content.Contains($needle)) {
                $hasOldWords = $true
                break
            }
        }
        Write-Host "[local] page_status=$($page.StatusCode) has_project_snapshot=$hasSnapshot has_old_words=$hasOldWords"

        $healthUrl = ($Url.TrimEnd("/")) + "/api/health"
        $health = Invoke-WebRequest -UseBasicParsing -Uri $healthUrl -TimeoutSec 15
        Write-Host "[local] health_status=$($health.StatusCode)"
    } catch {
        Write-Warning "Public URL verification failed: $($_.Exception.Message)"
    }
}

Write-Host "[local] deployment complete: $commit"
