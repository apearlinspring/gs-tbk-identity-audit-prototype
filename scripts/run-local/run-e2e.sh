#!/usr/bin/env bash
set -euo pipefail

MANIFEST_SCHEMA_VERSION="gstbk.e2e.manifest.v2"
SCRIPT_VERSION="run-e2e.sh role-entrypoints"
start_epoch="$(date +%s)"
start_timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
original_command="$(printf '%q ' "$0" "$@")"
original_command="${original_command% }"
current_step="initializing"

usage() {
  cat >&2 <<'EOF'
Usage: bash scripts/run-local/run-e2e.sh [options]

Options:
  --users <count>                       User count. Default: 2.
  --nodes <count>                       Node count. Default: 4.
  --runtime-dir <path>                  Runtime root. Default: /tmp/gstbk-e2e-smoke.
  --reuse-chain                         Reuse the already running FISCO BCOS chain.
  --contract-addresses-from-env         Use GSTBK_*_CONTRACT_ADDRESS from environment.
  --host <ip-or-hostname>               Local role advertised host. Default: 127.0.0.1.
  --timeout-seconds <seconds>           Per-wait timeout. Default: 240.
  --legacy-fixture-configs              Render configs into Git-tracked legacy fixture paths.
  --keep-rendered-configs               Keep legacy fixture config edits for debugging.
EOF
}

users="2"
nodes="4"
runtime_dir="/tmp/gstbk-e2e-smoke"
reuse_chain="false"
contract_addresses_from_env="false"
host="127.0.0.1"
timeout_seconds="240"
keep_rendered_configs="false"
legacy_fixture_configs="false"
proxy_port="50000"
node_port_start="50001"
user_port_start="60001"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --users)
      users="${2:?--users requires a value}"
      shift 2
      ;;
    --nodes)
      nodes="${2:?--nodes requires a value}"
      shift 2
      ;;
    --runtime-dir)
      runtime_dir="${2:?--runtime-dir requires a value}"
      shift 2
      ;;
    --reuse-chain)
      reuse_chain="true"
      shift
      ;;
    --contract-addresses-from-env)
      contract_addresses_from_env="true"
      shift
      ;;
    --host)
      host="${2:?--host requires a value}"
      shift 2
      ;;
    --timeout-seconds)
      timeout_seconds="${2:?--timeout-seconds requires a value}"
      shift 2
      ;;
    --keep-rendered-configs)
      keep_rendered_configs="true"
      shift
      ;;
    --legacy-fixture-configs)
      legacy_fixture_configs="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

is_uint() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

if ! is_uint "$nodes" || [ "$nodes" -lt 1 ] || [ "$nodes" -gt 4 ]; then
  echo "--nodes currently supports 1..4" >&2
  exit 2
fi

if ! is_uint "$users" || [ "$users" -lt 1 ] || [ "$users" -gt 6 ]; then
  echo "--users currently supports 1..6" >&2
  exit 2
fi

if ! is_uint "$timeout_seconds" || [ "$timeout_seconds" -lt 1 ]; then
  echo "--timeout-seconds must be a positive integer" >&2
  exit 2
fi

if [ "$reuse_chain" != "true" ]; then
  echo "run-e2e.sh currently supports --reuse-chain only; start or deploy FISCO BCOS separately and rerun with --reuse-chain." >&2
  exit 2
fi

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$runtime_dir"
runtime_dir="$(cd "$runtime_dir" && pwd)"
state_dir="$runtime_dir/runtime-state/$timestamp"
log_dir="$runtime_dir/runtime-logs/$timestamp"
chain_log_dir="$log_dir/chain"
identity_dir="$state_dir/identity"
runtime_config_dir="$state_dir/runtime-config"
active_runtime_config_dir="$runtime_config_dir"
config_mode="runtime"
if [ "$legacy_fixture_configs" = "true" ]; then
  active_runtime_config_dir=""
  config_mode="legacy_fixture"
fi
config_backup_dir="$state_dir/config-backup"
mkdir -p "$state_dir" "$log_dir" "$chain_log_dir" "$identity_dir"
if [ "$legacy_fixture_configs" != "true" ]; then
  mkdir -p "$runtime_config_dir"
fi

python_bin="${PYTHON_BIN:-python3}"
if ! command -v "$python_bin" >/dev/null 2>&1; then
  python_bin="python"
fi

role_pids=()
role_names=()
role_logs=()
rendered_config_paths=()
roles_cleaned_up="false"
configs_backed_up="false"
configs_restored="not-applicable"

print_tails() {
  echo "---- last role logs ----" >&2
  local log
  for log in "${role_logs[@]:-}"; do
    if [ -f "$log" ]; then
      echo "==> $log" >&2
      tail -n 80 "$log" >&2 || true
    fi
  done
}

cleanup_roles() {
  if [ "$roles_cleaned_up" = "true" ]; then
    return
  fi

  local pid
  for pid in "${role_pids[@]:-}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill -TERM "-$pid" >/dev/null 2>&1 || kill -TERM "$pid" >/dev/null 2>&1 || true
    fi
  done
  sleep 1
  for pid in "${role_pids[@]:-}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill -KILL "-$pid" >/dev/null 2>&1 || kill -KILL "$pid" >/dev/null 2>&1 || true
    fi
    wait "$pid" >/dev/null 2>&1 || true
  done
  roles_cleaned_up="true"
}

collect_role_file_logs() {
  local index src dst
  for index in $(seq 1 "$nodes"); do
    src="$repo_root/crates/intergration_test/src/node/node${index}/logs/node.log"
    dst="$log_dir/node${index}.log4rs.log"
    if [ -f "$src" ] && [ -f "$log_dir/node${index}.out" ]; then
      cp "$src" "$dst"
    fi
  done
}

collect_rendered_config_paths() {
  rendered_config_paths=(
    "crates/intergration_test/src/proxy/config/config_file/proxy_config.json"
  )

  local index
  for index in $(seq 1 "$nodes"); do
    rendered_config_paths+=(
      "crates/intergration_test/src/node/node${index}/config/config_file/node_config.json"
    )
  done
  for index in $(seq 1 "$users"); do
    rendered_config_paths+=(
      "crates/intergration_test/src/user/user${index}/config/config_file/user_config.json"
    )
  done
}

backup_rendered_configs() {
  collect_rendered_config_paths
  rm -rf "$config_backup_dir"
  mkdir -p "$config_backup_dir"

  local rel src dst
  for rel in "${rendered_config_paths[@]}"; do
    src="$repo_root/$rel"
    dst="$config_backup_dir/$rel"
    mkdir -p "$(dirname "$dst")"
    if [ -f "$src" ]; then
      cp "$src" "$dst"
    else
      touch "$dst.__missing"
    fi
  done
  configs_backed_up="true"
}

restore_rendered_configs() {
  if [ "$configs_restored" = "true" ] || [ "$configs_backed_up" != "true" ]; then
    return
  fi

  if [ "$keep_rendered_configs" = "true" ]; then
    configs_restored="skipped"
    return
  fi

  local rel src dst
  for rel in "${rendered_config_paths[@]}"; do
    src="$repo_root/$rel"
    dst="$config_backup_dir/$rel"
    if [ -f "$dst.__missing" ]; then
      rm -f "$src"
    else
      mkdir -p "$(dirname "$src")"
      cp "$dst" "$src"
    fi
  done
  configs_restored="true"
}

cleanup() {
  cleanup_roles
  restore_rendered_configs
}

fail() {
  local message="$1"
  local code="${2:-1}"
  echo "$message" >&2
  print_tails
  cleanup_roles
  collect_role_file_logs || true
  restore_rendered_configs
  write_manifest false "failed during ${current_step}: ${message}" || true
  exit "$code"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Required command not found: $1" 2
  fi
}

require_env() {
  local name="$1"
  local value
  value="$(printenv "$name" || true)"
  if [ -z "$value" ]; then
    fail "Missing required environment variable: $name" 2
  fi
}

require_file() {
  local path="$1"
  local label="$2"
  if [ ! -f "$path" ]; then
    fail "$label not found: $path" 2
  fi
}

require_identity_inputs() {
  local index input
  for index in $(seq 1 "$users"); do
    input="$repo_root/examples/id-info/user${index}.json"
    if [ ! -f "$input" ]; then
      fail "Missing identity input sample for user${index}: $input" 2
    fi
  done
}

port_is_listening() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltnH | awk '{print $4}' | grep -Eq "(^|:)$port$"
  elif command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
  else
    return 1
  fi
}

check_port_free() {
  local port="$1"
  if port_is_listening "$port"; then
    fail "Port already in use: $port" 2
  fi
}

wait_for_port() {
  local port="$1"
  local label="$2"
  local deadline=$((SECONDS + timeout_seconds))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if port_is_listening "$port"; then
      echo "$label is listening on port $port"
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for $label on port $port" >&2
  return 1
}

wait_for_log() {
  local log_file="$1"
  local pattern="$2"
  local label="$3"
  local deadline=$((SECONDS + timeout_seconds))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if [ -f "$log_file" ] && grep -Fq "$pattern" "$log_file"; then
      echo "$label: matched '$pattern'"
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for '$pattern' in $log_file" >&2
  return 1
}

start_role() {
  local name="$1"
  shift
  local log_file="$log_dir/$name.out"
  printf '%q ' "$@" > "$log_dir/$name.command"
  printf '\n' >> "$log_dir/$name.command"
  if command -v setsid >/dev/null 2>&1; then
    setsid "$@" >"$log_file" 2>&1 &
  else
    "$@" >"$log_file" 2>&1 &
  fi
  local pid="$!"
  role_pids+=("$pid")
  role_names+=("$name")
  role_logs+=("$log_file")
  echo "$name pid $pid log $log_file"
}

extract_value() {
  local key="$1"
  local file="$2"
  awk -v key="$key" '$1 == key {print $2; exit}' "$file"
}

run_chain_command() {
  local output="$1"
  shift
  "$@" >"$output" 2>&1
  cat "$output"
}

write_manifest() {
  local success="$1"
  local error_message="${2:-}"
  local end_epoch end_timestamp elapsed_seconds
  end_epoch="$(date +%s)"
  end_timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  elapsed_seconds=$((end_epoch - start_epoch))

  SCHEMA_VERSION="$MANIFEST_SCHEMA_VERSION" \
  SCRIPT_VERSION="$SCRIPT_VERSION" \
  START_TIMESTAMP="$start_timestamp" \
  END_TIMESTAMP="$end_timestamp" \
  ELAPSED_SECONDS="$elapsed_seconds" \
  SUCCESS="$success" \
  ERROR_MESSAGE="$error_message" \
  REPO_ROOT="$repo_root" \
  RUNTIME_DIR="$runtime_dir" \
  STATE_DIR="$state_dir" \
  LOG_DIR="$log_dir" \
  CHAIN_LOG_DIR="$chain_log_dir" \
  CONFIG_MODE="$config_mode" \
  RUNTIME_CONFIG_DIR="$active_runtime_config_dir" \
  USERS="$users" \
  NODES="$nodes" \
  USER_PREFIX="${user_prefix:-}" \
  USER_SUFFIX="${user_suffix:-}" \
  REUSE_CHAIN="$reuse_chain" \
  KEEP_RENDERED_CONFIGS="$keep_rendered_configs" \
  CONFIGS_RESTORED="$configs_restored" \
  LEGACY_FIXTURE_CONFIGS="$legacy_fixture_configs" \
  CONTRACT_ADDRESSES_FROM_ENV="$contract_addresses_from_env" \
  PERSONAL_INFO_ADDRESS="${GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS:-}" \
  SIGNATURE_ADDRESS="${GSTBK_SIGNATURE_CONTRACT_ADDRESS:-}" \
  FISCO_CONFIG_VALUE="${FISCO_CONFIG:-}" \
  FISCO_GROUP_VALUE="${FISCO_GROUP:-}" \
  COMMAND_LINE="$original_command" \
  HOST="$host" \
  PROXY_PORT="$proxy_port" \
  NODE_PORT_START="$node_port_start" \
  USER_PORT_START="$user_port_start" \
  "$python_bin" <<'PY'
import hashlib
import json
import os
import subprocess
from pathlib import Path

repo = Path(os.environ["REPO_ROOT"])
log_dir = Path(os.environ["LOG_DIR"])
chain_log_dir = Path(os.environ["CHAIN_LOG_DIR"])
state_dir = Path(os.environ["STATE_DIR"])
users = int(os.environ["USERS"])
nodes = int(os.environ["NODES"])
user_prefix = os.environ.get("USER_PREFIX", "")
user_suffix = os.environ.get("USER_SUFFIX", "")

def sha256_if_exists(path: Path):
    if not path.exists() or not path.is_file():
        return None
    return hashlib.sha256(path.read_bytes()).hexdigest()

def text_if_exists(path: Path):
    if not path.exists() or not path.is_file():
        return None
    return path.read_text(encoding="utf-8", errors="replace").strip()

def command_output(args):
    try:
        return subprocess.check_output(
            args,
            cwd=repo,
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

def parse_registers(path: Path):
    result = {}
    if not path.exists():
        return result
    current = None
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("Signature register stdout:"):
            current = "signature"
            result[current] = {}
        elif line.startswith("PersonalInfo register stdout:"):
            current = "personal_info"
            result[current] = {}
        elif current and line.startswith("transactionHash "):
            result[current]["transaction_hash"] = line.split(maxsplit=1)[1]
        elif current and line.startswith("blockNumber "):
            result[current]["block_number"] = line.split(maxsplit=1)[1]
        elif current and line.startswith("ret "):
            result[current]["ret"] = line.split(maxsplit=1)[1]
    return result

def first_value(path: Path, key: str):
    if not path.exists():
        return None
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith(key + " "):
            return line.split(maxsplit=1)[1]
    return None

def source_file(rel: str):
    path = repo / rel
    return {"path": str(path), "sha256": sha256_if_exists(path)}

git_commit = command_output(["git", "rev-parse", "HEAD"])
git_branch = command_output(["git", "rev-parse", "--abbrev-ref", "HEAD"])
git_status = command_output(["git", "status", "--short"])
is_git_repo = git_commit is not None

role_logs = {}
role_names = ["proxy"]
role_names.extend(f"node{i}" for i in range(1, nodes + 1))
role_names.extend(f"user{i}" for i in range(1, users + 1))
for name in role_names:
    path = log_dir / f"{name}.out"
    command_path = log_dir / f"{name}.command"
    file_log_path = log_dir / f"{name}.log4rs.log"
    sources = []
    role_logs[name] = {
        "command": text_if_exists(command_path),
        "command_path": str(command_path),
        "command_sha256": sha256_if_exists(command_path),
    }
    if path.exists():
        role_logs[name].update({"path": str(path), "sha256": sha256_if_exists(path)})
        sources.append({"kind": "stdout", "path": str(path), "sha256": sha256_if_exists(path)})
    if file_log_path.exists():
        role_logs[name].update(
            {
                "file_log_path": str(file_log_path),
                "file_log_sha256": sha256_if_exists(file_log_path),
            }
        )
        sources.append(
            {
                "kind": "log4rs_file",
                "path": str(file_log_path),
                "sha256": sha256_if_exists(file_log_path),
            }
        )
    if sources:
        role_logs[name]["sources"] = sources

identity_outputs = {}
chain_results = {}
for index in range(1, users + 1):
    user_name = f"{user_prefix}{index}{user_suffix}"
    identity_path = state_dir / "identity" / f"user{index}-block-personal-info.json"
    user_log = log_dir / f"user{index}.out"
    selects = {
        "signature_select": chain_log_dir / f"user{index}-signature-select.out",
        "personal_info_select": chain_log_dir / f"user{index}-info-select.out",
    }
    identity_outputs[f"user{index}"] = {
        "user_name": user_name,
        "input": str(repo / "examples" / "id-info" / f"user{index}.json"),
        "output": str(identity_path),
        "sha256": sha256_if_exists(identity_path),
    }
    chain_results[f"user{index}"] = {
        "user_name": user_name,
        "registers": parse_registers(user_log),
        "selects": {
            key: {
                "path": str(path),
                "exists": first_value(path, "exists"),
                "sha256": sha256_if_exists(path),
            }
            for key, path in selects.items()
            if path.exists()
        },
    }

source_snapshot = {
    "repo_root": str(repo),
    "is_git_repo": is_git_repo,
}
if not is_git_repo:
    source_snapshot["files"] = {
        rel: source_file(rel)
        for rel in [
            "scripts/run-local/run-e2e.sh",
            "scripts/run-local/render-configs.sh",
            "scripts/run-local/run-id-info.sh",
            "scripts/run-local/run-node.sh",
            "scripts/run-local/run-user.sh",
            "examples/id-info/user1.json",
            "examples/id-info/user2.json",
        ]
    }

ports = {
    "host": os.environ["HOST"],
    "proxy": int(os.environ["PROXY_PORT"]),
    "nodes": [
        int(os.environ["NODE_PORT_START"]) + index - 1
        for index in range(1, nodes + 1)
    ],
    "users": [
        int(os.environ["USER_PORT_START"]) + index - 1
        for index in range(1, users + 1)
    ],
}

runtime_config_dir = os.environ.get("RUNTIME_CONFIG_DIR")
if runtime_config_dir:
    config_root = Path(runtime_config_dir)
    config_paths = {
        "proxy": str(config_root / "proxy" / "proxy_config.json"),
        "nodes": [
            str(config_root / "node" / f"node{index}" / "node_config.json")
            for index in range(1, nodes + 1)
        ],
        "users": [
            str(config_root / "user" / f"user{index}" / "user_config.json")
            for index in range(1, users + 1)
        ],
    }
else:
    config_paths = {
        "proxy": str(repo / "crates/intergration_test/src/proxy/config/config_file/proxy_config.json"),
        "nodes": [
            str(repo / f"crates/intergration_test/src/node/node{index}/config/config_file/node_config.json")
            for index in range(1, nodes + 1)
        ],
        "users": [
            str(repo / f"crates/intergration_test/src/user/user{index}/config/config_file/user_config.json")
            for index in range(1, users + 1)
        ],
    }

success = os.environ["SUCCESS"] == "true"
manifest = {
    "schema_version": os.environ["SCHEMA_VERSION"],
    "script_version": os.environ["SCRIPT_VERSION"],
    "start_timestamp": os.environ["START_TIMESTAMP"],
    "end_timestamp": os.environ["END_TIMESTAMP"],
    "elapsed_seconds": int(os.environ["ELAPSED_SECONDS"]),
    "success": success,
    "error": None if success else os.environ.get("ERROR_MESSAGE", ""),
    "command": os.environ["COMMAND_LINE"],
    "git": {
        "commit": git_commit,
        "branch": git_branch,
        "status_short": git_status,
    },
    "source_snapshot": source_snapshot,
    "runtime": {
        "runtime_dir": os.environ["RUNTIME_DIR"],
        "state_dir": os.environ["STATE_DIR"],
        "log_dir": os.environ["LOG_DIR"],
        "reuse_chain": os.environ["REUSE_CHAIN"] == "true",
        "contract_addresses_from_env": os.environ["CONTRACT_ADDRESSES_FROM_ENV"] == "true",
    },
    "config": {
        "mode": os.environ["CONFIG_MODE"],
        "runtime_config_dir": os.environ.get("RUNTIME_CONFIG_DIR") or None,
        "paths": config_paths,
        "legacy_fixture_configs": os.environ["LEGACY_FIXTURE_CONFIGS"] == "true",
        "keep_rendered_configs": os.environ["KEEP_RENDERED_CONFIGS"] == "true",
        "configs_restored": os.environ["CONFIGS_RESTORED"],
    },
    "ports": ports,
    "roles": {
        "proxy": 1,
        "nodes": nodes,
        "users": users,
        "logs": role_logs,
    },
    "chain": {
        "fisco_config": os.environ.get("FISCO_CONFIG_VALUE"),
        "fisco_group": os.environ.get("FISCO_GROUP_VALUE"),
        "contracts": {
            "personal_info": os.environ.get("PERSONAL_INFO_ADDRESS"),
            "signature": os.environ.get("SIGNATURE_ADDRESS"),
        },
        "block_before": first_value(chain_log_dir / "block-before.out", "blockNumber"),
        "block_after": first_value(chain_log_dir / "block-after.out", "blockNumber"),
    },
    "identity": identity_outputs,
    "chain_results": chain_results,
}

manifest_path = log_dir / "manifest.json"
manifest_path.write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
print(f"manifestPath {manifest_path}")
PY
}

on_error() {
  local exit_code=$?
  trap - ERR
  local error_message="failed during ${current_step} (exit ${exit_code})"
  print_tails
  cleanup_roles
  collect_role_file_logs || true
  restore_rendered_configs
  write_manifest false "$error_message" || true
  exit "$exit_code"
}

trap on_error ERR
trap cleanup EXIT

current_step="checking required commands"
require_command cargo
require_command "$python_bin"

current_step="validating environment"
if [ -z "${FISCO_CONSOLE_DIR:-}" ] && [ -d "$HOME/fisco/console/lib" ]; then
  export FISCO_CONSOLE_DIR="$HOME/fisco/console"
fi
require_env FISCO_CONFIG
require_env FISCO_GROUP
require_env GSTBK_PERSONAL_INFO_APP_DIR
require_env GSTBK_SIGNATURE_APP_DIR
require_file "$FISCO_CONFIG" "FISCO_CONFIG"
require_file "$GSTBK_PERSONAL_INFO_APP_DIR/info_run.sh" "GSTBK_PERSONAL_INFO_APP_DIR/info_run.sh"
require_file "$GSTBK_SIGNATURE_APP_DIR/signature_run.sh" "GSTBK_SIGNATURE_APP_DIR/signature_run.sh"

if [ "$contract_addresses_from_env" = "true" ]; then
  require_env GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS
  require_env GSTBK_SIGNATURE_CONTRACT_ADDRESS
fi

current_step="checking chain health"
block_before="$chain_log_dir/block-before.out"
run_chain_command "$block_before" bash "$GSTBK_PERSONAL_INFO_APP_DIR/info_run.sh" blockNumber

current_step="checking ports"
check_port_free "$proxy_port"
for index in $(seq 1 "$nodes"); do
  check_port_free "$((node_port_start + index - 1))"
done
for index in $(seq 1 "$users"); do
  check_port_free "$((user_port_start + index - 1))"
done

current_step="checking identity input samples"
require_identity_inputs

export GSTBK_RUNTIME_DIR="$state_dir"
export GSTBK_RUNTIME_STATE_DIR="$state_dir"
export GSTBK_CL_KEYPAIR_PATH="$state_dir/cl_keypair.json"
export LD_LIBRARY_PATH="$repo_root/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"
unset GSTBK_PROXY_CONFIG_PATH GSTBK_NODE_CONFIG_PATH GSTBK_USER_CONFIG_PATH
unset GSTBK_NODE_INFO_DIR GSTBK_USER_INFO_DIR

current_step="preparing contract addresses"
if [ "$contract_addresses_from_env" != "true" ]; then
  personal_deploy="$chain_log_dir/personalInfo-deploy.out"
  signature_deploy="$chain_log_dir/signature-deploy.out"
  run_chain_command "$personal_deploy" bash "$GSTBK_PERSONAL_INFO_APP_DIR/info_run.sh" deploy
  run_chain_command "$signature_deploy" bash "$GSTBK_SIGNATURE_APP_DIR/signature_run.sh" deploy
  export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS
  export GSTBK_SIGNATURE_CONTRACT_ADDRESS
  GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS="$(extract_value contractAddress "$personal_deploy")"
  GSTBK_SIGNATURE_CONTRACT_ADDRESS="$(extract_value contractAddress "$signature_deploy")"
  if [ -z "$GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" ] || [ -z "$GSTBK_SIGNATURE_CONTRACT_ADDRESS" ]; then
    fail "Failed to deploy or extract contract addresses" 1
  fi
fi

if [ "$legacy_fixture_configs" = "true" ]; then
  current_step="backing up rendered configs"
  backup_rendered_configs
fi

user_prefix="e2e${timestamp}_user"
user_suffix=""
current_step="rendering local configs"
render_config_args=(
  scripts/run-local/render-configs.sh
  --mode local
  --host "$host"
  --nodes "$nodes"
  --users "$users"
  --threshold 2
  --proxy-port "$proxy_port"
  --node-port-start "$node_port_start"
  --user-port-start "$user_port_start"
  --user-name-prefix "$user_prefix"
  --user-name-suffix "$user_suffix"
)
if [ "$legacy_fixture_configs" = "true" ]; then
  env -u GSTBK_RUNTIME_CONFIG_DIR bash "${render_config_args[@]}" >"$log_dir/render-configs.out"
  unset GSTBK_RUNTIME_CONFIG_DIR
else
  bash "${render_config_args[@]}" --output-dir "$runtime_config_dir" >"$log_dir/render-configs.out"
  export GSTBK_RUNTIME_CONFIG_DIR="$runtime_config_dir"
fi

current_step="generating CL keypair"
bash scripts/run-local/run-id-info.sh keygen >"$log_dir/id-info-keygen.out" 2>&1

for index in $(seq 1 "$users"); do
  current_step="generating identity payload for user${index}"
  input="examples/id-info/user${index}.json"
  output="$identity_dir/user${index}-block-personal-info.json"
  GSTBK_ID_INFO_INPUT_PATH="$repo_root/$input" \
  GSTBK_ID_INFO_OUTPUT_PATH="$output" \
    bash scripts/run-local/run-id-info.sh enc >"$log_dir/id-info-user${index}-enc.out" 2>&1

  current_step="verifying identity payload for user${index}"
  GSTBK_ID_INFO_OUTPUT_PATH="$output" \
    bash scripts/run-local/run-id-info.sh verify >"$log_dir/id-info-user${index}-verify.out" 2>&1
done

current_step="starting proxy"
start_role proxy bash scripts/run-local/run-proxy.sh
wait_for_port "$proxy_port" proxy

for index in $(seq 1 "$nodes"); do
  current_step="starting node${index}"
  start_role "node${index}" bash scripts/run-local/run-node.sh "$index"
  wait_for_port "$((node_port_start + index - 1))" "node${index}"
done

current_step="waiting for proxy keygen"
wait_for_log "$log_dir/proxy.out" "Keygen phase is finished!" proxy-keygen

for index in $(seq 1 "$users"); do
  current_step="starting user${index}"
  payload="$identity_dir/user${index}-block-personal-info.json"
  start_role "user${index}" env GSTBK_PERSONAL_INFO_PAYLOAD_PATH="$payload" bash scripts/run-local/run-user.sh "$index"
  wait_for_port "$((user_port_start + index - 1))" "user${index}"
done

for index in $(seq 1 "$users"); do
  current_step="waiting for user${index} flow"
  wait_for_log "$log_dir/user${index}.out" "Join phase is finished!" "user${index}-join"
  wait_for_log "$log_dir/user${index}.out" "Sign phase is finished!" "user${index}-sign"
  wait_for_log "$log_dir/user${index}.out" "Signature register stdout:" "user${index}-signature-register"
  wait_for_log "$log_dir/user${index}.out" "PersonalInfo register stdout:" "user${index}-personal-info-register"
done

for index in $(seq 1 "$nodes"); do
  current_step="waiting for node${index} open"
  wait_for_log "$log_dir/node${index}.out" "Open phase is finished!" "node${index}-open"
done

current_step="checking final block number"
block_after="$chain_log_dir/block-after.out"
run_chain_command "$block_after" bash "$GSTBK_PERSONAL_INFO_APP_DIR/info_run.sh" blockNumber

for index in $(seq 1 "$users"); do
  current_step="querying chain data for user${index}"
  user_name="${user_prefix}${index}${user_suffix}"
  run_chain_command "$chain_log_dir/user${index}-signature-select.out" \
    bash "$GSTBK_SIGNATURE_APP_DIR/signature_run.sh" select "$user_name"
  run_chain_command "$chain_log_dir/user${index}-info-select.out" \
    bash "$GSTBK_PERSONAL_INFO_APP_DIR/info_run.sh" select "$user_name"
done

current_step="cleaning up roles"
cleanup_roles
collect_role_file_logs
restore_rendered_configs

current_step="writing success manifest"
write_manifest true ""

echo "E2E complete"
echo "logDir $log_dir"
echo "manifest $log_dir/manifest.json"
