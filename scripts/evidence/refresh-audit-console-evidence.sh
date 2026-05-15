#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/evidence/refresh-audit-console-evidence.sh --manifest <manifest.json> [options]

Options:
  -m, --manifest <path>       run-e2e manifest JSON to summarize.
      --console-root <path>   Audit console repo/deploy root. Default: current repo root.
      --target-dir <path>     Evidence install directory. Default: <console-root>/docs/evidence.
      --work-dir <path>       Scratch output directory. Default: /tmp/gstbk-console-refresh-<timestamp>.
      --prefix <name>         Installed file prefix. Default: console-current.
      --user <name>           Limit evidence generation to one manifest key, user id, or user name. May repeat.
      --dry-run-audit         Generate audit-query commands without connecting to FISCO BCOS.
      --skip-audit-query      Only refresh malicious-open summary.
      --skip-malicious-open   Only refresh audit-query summary.
      --no-check              Skip audit-console --check after installing JSON summaries.
      --restart-service [name]
                            Restart systemd service after refresh. Default name: gstbk-audit-console.
  -h, --help                  Show this help.

This script does not start GS-TBK roles. Run E2E first, then pass the generated manifest.
EOF
}

manifest_path=""
console_root=""
target_dir=""
work_dir=""
prefix="console-current"
dry_run_audit="false"
skip_audit_query="false"
skip_malicious_open="false"
run_check="true"
restart_service="false"
service_name="gstbk-audit-console"
user_filters=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    -m|--manifest)
      manifest_path="${2:?--manifest requires a value}"
      shift 2
      ;;
    --console-root)
      console_root="${2:?--console-root requires a value}"
      shift 2
      ;;
    --target-dir)
      target_dir="${2:?--target-dir requires a value}"
      shift 2
      ;;
    --work-dir)
      work_dir="${2:?--work-dir requires a value}"
      shift 2
      ;;
    --prefix)
      prefix="${2:?--prefix requires a value}"
      shift 2
      ;;
    --user)
      user_filters+=("${2:?--user requires a value}")
      shift 2
      ;;
    --dry-run-audit)
      dry_run_audit="true"
      shift
      ;;
    --skip-audit-query)
      skip_audit_query="true"
      shift
      ;;
    --skip-malicious-open)
      skip_malicious_open="true"
      shift
      ;;
    --no-check)
      run_check="false"
      shift
      ;;
    --restart-service)
      restart_service="true"
      if [ "${2:-}" != "" ] && [[ "${2:-}" != -* ]]; then
        service_name="$2"
        shift 2
      else
        shift
      fi
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      if [ -z "$manifest_path" ]; then
        manifest_path="$1"
      else
        echo "Unexpected argument: $1" >&2
        usage
        exit 2
      fi
      shift
      ;;
  esac
done

if [ -z "$manifest_path" ]; then
  echo "Missing manifest path." >&2
  usage
  exit 2
fi

if [ "$skip_audit_query" = "true" ] && [ "$skip_malicious_open" = "true" ]; then
  echo "Nothing to refresh: both --skip-audit-query and --skip-malicious-open were set." >&2
  exit 2
fi

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

abs_path() {
  local path="$1"
  if [ -z "$path" ]; then
    return 0
  fi
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$path"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve())' "$path"
  elif command -v python >/dev/null 2>&1; then
    python -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve())' "$path"
  elif [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$PWD" "$path"
  fi
}

require_file() {
  local path="$1"
  local label="$2"
  if [ ! -f "$path" ]; then
    echo "$label not found: $path" >&2
    exit 2
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 2
  fi
}

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [ -f "$src" ]; then
    install -m 0644 "$src" "$dst"
    echo "installed $dst"
  fi
}

run_systemctl() {
  local action="$1"
  local unit="$2"
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "systemctl not found; cannot $action $unit" >&2
    exit 2
  fi
  if [ "$(id -u)" -eq 0 ]; then
    systemctl "$action" "$unit"
  else
    sudo systemctl "$action" "$unit"
  fi
}

manifest_path="$(abs_path "$manifest_path")"
require_file "$manifest_path" "Manifest"
require_file "$repo_root/scripts/evidence/run-audit-query-demo.sh" "run-audit-query-demo.sh"
require_file "$repo_root/scripts/evidence/run-malicious-open-demo.sh" "run-malicious-open-demo.sh"

if [ -z "$console_root" ]; then
  console_root="$repo_root"
fi
console_root="$(abs_path "$console_root")"

if [ -z "$target_dir" ]; then
  target_dir="$console_root/docs/evidence"
else
  target_dir="$(abs_path "$target_dir")"
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
if [ -z "$work_dir" ]; then
  work_dir="${TMPDIR:-/tmp}/gstbk-console-refresh-$timestamp"
else
  work_dir="$(abs_path "$work_dir")"
fi

mkdir -p "$work_dir" "$target_dir"

user_args=()
for user in "${user_filters[@]}"; do
  user_args+=(--user "$user")
done

echo "manifest $manifest_path"
echo "workDir $work_dir"
echo "targetDir $target_dir"

if [ "$skip_audit_query" != "true" ]; then
  audit_dir="$work_dir/audit-query"
  audit_json="$audit_dir/audit-query-summary.json"
  mkdir -p "$audit_dir"
  audit_args=(
    bash "$repo_root/scripts/evidence/run-audit-query-demo.sh"
    --manifest "$manifest_path"
    --output-dir "$audit_dir"
    --json-output "$audit_json"
  )
  if [ "$dry_run_audit" = "true" ]; then
    audit_args+=(--dry-run)
  fi
  audit_args+=("${user_args[@]}")
  "${audit_args[@]}"
  copy_if_exists "$audit_json" "$target_dir/$prefix-audit-query.json"
  copy_if_exists "$audit_dir/audit-query-summary.md" "$target_dir/$prefix-audit-query.md"
fi

if [ "$skip_malicious_open" != "true" ]; then
  malicious_dir="$work_dir/malicious-open"
  malicious_json="$malicious_dir/malicious-open-summary.json"
  mkdir -p "$malicious_dir"
  malicious_args=(
    bash "$repo_root/scripts/evidence/run-malicious-open-demo.sh"
    --manifest "$manifest_path"
    --output-dir "$malicious_dir"
    --json-output "$malicious_json"
  )
  malicious_args+=("${user_args[@]}")
  "${malicious_args[@]}"
  copy_if_exists "$malicious_json" "$target_dir/$prefix-malicious-open.json"
  copy_if_exists "$malicious_dir/malicious-open-summary.md" "$target_dir/$prefix-malicious-open.md"
fi

if [ "$run_check" = "true" ]; then
  require_command "${NODE_BIN:-node}"
  require_file "$console_root/apps/audit-console/server.mjs" "audit console server"
  (cd "$console_root" && "${NODE_BIN:-node}" apps/audit-console/server.mjs --check)
fi

if [ "$restart_service" = "true" ]; then
  run_systemctl restart "$service_name"
  run_systemctl is-active "$service_name"
fi

echo "refreshComplete true"
