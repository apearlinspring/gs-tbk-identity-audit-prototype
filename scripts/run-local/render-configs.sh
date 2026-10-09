#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: bash scripts/run-local/render-configs.sh [options]

Options:
  --mode <local|multi-host>      Addressing mode. Default: local.
  --host <ip-or-hostname>        Advertised Proxy/Node/User host. Default: 127.0.0.1.
  --nodes <count>                Node count, currently 1..4. Default: 4.
  --users <count>                User count, currently 1..6. Default: 2.
  --threshold <count>            Threshold value. Default: 2.
  --proxy-port <port>            Proxy port. Default: 50000.
  --node-port-start <port>       First Node port. Default: 50001.
  --user-port-start <port>       First User port. Default: 60001.
  --listen-host <host>           Bind/listen host. Default: 0.0.0.0.
  --user-name-prefix <prefix>    User name prefix. Default: user.
  --user-name-suffix <suffix>    User name suffix. Default: _test_32.
  --output-dir <path>            Runtime config root. Default: GSTBK_RUNTIME_CONFIG_DIR, then legacy fixtures.
EOF
}

mode="local"
host="127.0.0.1"
nodes="4"
users="2"
threshold="2"
proxy_port="50000"
node_port_start="50001"
user_port_start="60001"
listen_host="0.0.0.0"
user_name_prefix="user"
user_name_suffix="_test_32"
output_dir="${GSTBK_RUNTIME_CONFIG_DIR:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      mode="${2:?--mode requires a value}"
      shift 2
      ;;
    --host)
      host="${2:?--host requires a value}"
      shift 2
      ;;
    --nodes)
      nodes="${2:?--nodes requires a value}"
      shift 2
      ;;
    --users)
      users="${2:?--users requires a value}"
      shift 2
      ;;
    --threshold)
      threshold="${2:?--threshold requires a value}"
      shift 2
      ;;
    --proxy-port)
      proxy_port="${2:?--proxy-port requires a value}"
      shift 2
      ;;
    --node-port-start)
      node_port_start="${2:?--node-port-start requires a value}"
      shift 2
      ;;
    --user-port-start)
      user_port_start="${2:?--user-port-start requires a value}"
      shift 2
      ;;
    --listen-host)
      listen_host="${2:?--listen-host requires a value}"
      shift 2
      ;;
    --user-name-prefix)
      user_name_prefix="${2:?--user-name-prefix requires a value}"
      shift 2
      ;;
    --user-name-suffix)
      if [ "$#" -lt 2 ]; then
        echo "--user-name-suffix requires a value" >&2
        exit 2
      fi
      user_name_suffix="$2"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:?--output-dir requires a value}"
      shift 2
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

if [ "$mode" != "local" ] && [ "$mode" != "multi-host" ]; then
  echo "--mode must be local or multi-host" >&2
  exit 2
fi

if [ "$nodes" -lt 1 ] || [ "$nodes" -gt 4 ]; then
  echo "--nodes currently supports 1..4 because only node1..node4 test modules exist" >&2
  exit 2
fi

if [ "$users" -lt 1 ] || [ "$users" -gt 6 ]; then
  echo "--users currently supports 1..6 because only user1..user6 test modules exist" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
python_bin="${PYTHON_BIN:-python3}"
if ! command -v "$python_bin" >/dev/null 2>&1; then
  python_bin="python"
fi

REPO_ROOT="$repo_root" \
MODE="$mode" \
HOST="$host" \
NODES="$nodes" \
USERS="$users" \
THRESHOLD="$threshold" \
PROXY_PORT="$proxy_port" \
NODE_PORT_START="$node_port_start" \
USER_PORT_START="$user_port_start" \
LISTEN_HOST="$listen_host" \
USER_NAME_PREFIX="$user_name_prefix" \
USER_NAME_SUFFIX="$user_name_suffix" \
OUTPUT_DIR="$output_dir" \
"$python_bin" <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["REPO_ROOT"])
host = os.environ["HOST"]
nodes = int(os.environ["NODES"])
users = int(os.environ["USERS"])
threshold = int(os.environ["THRESHOLD"])
proxy_port = int(os.environ["PROXY_PORT"])
node_port_start = int(os.environ["NODE_PORT_START"])
user_port_start = int(os.environ["USER_PORT_START"])
listen_host = os.environ["LISTEN_HOST"]
user_name_prefix = os.environ["USER_NAME_PREFIX"]
user_name_suffix = os.environ["USER_NAME_SUFFIX"]
output_dir_value = os.environ.get("OUTPUT_DIR", "")
output_root = None
if output_dir_value:
    output_root = Path(output_dir_value)
    if not output_root.is_absolute():
        output_root = root / output_root

def display_path(path: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)

def proxy_config_path() -> Path:
    if output_root is not None:
        return output_root / "proxy" / "proxy_config.json"
    return root / "crates/intergration_test/src/proxy/config/config_file/proxy_config.json"

def node_config_path(index: int) -> Path:
    if output_root is not None:
        return output_root / "node" / f"node{index}" / "node_config.json"
    return root / f"crates/intergration_test/src/node/node{index}/config/config_file/node_config.json"

def user_config_path(index: int) -> Path:
    if output_root is not None:
        return output_root / "user" / f"user{index}" / "user_config.json"
    return root / f"crates/intergration_test/src/user/user{index}/config/config_file/user_config.json"

def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(display_path(path))

proxy_addr = f"{host}:{proxy_port}"
threshold_params = {"threshold": threshold, "share_counts": nodes}

write_json(
    proxy_config_path(),
    {
        "listen_addr": f"{listen_host}:{proxy_port}",
        "proxy_addr": proxy_addr,
        "threshold_params": threshold_params,
    },
)

for index in range(1, nodes + 1):
    port = node_port_start + index - 1
    write_json(
        node_config_path(index),
        {
            "proxy_addr": proxy_addr,
            "node_addr": f"{host}:{port}",
            "listen_addr": f"{listen_host}:{port}",
            "threshold_params": threshold_params,
        },
    )

for index in range(1, users + 1):
    port = user_port_start + index - 1
    write_json(
        user_config_path(index),
        {
            "proxy_addr": proxy_addr,
            "user_addr": f"{host}:{port}",
            "listen_addr": f"{listen_host}:{port}",
            "name": f"{user_name_prefix}{index}{user_name_suffix}",
        },
    )
PY
