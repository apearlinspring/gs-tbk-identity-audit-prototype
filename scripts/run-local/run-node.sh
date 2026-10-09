#!/usr/bin/env bash
set -euo pipefail

node_id="${1:-}"
if [[ ! "$node_id" =~ ^[1-4]$ ]]; then
  echo "Usage: bash scripts/run-local/run-node.sh <1|2|3|4>" >&2
  exit 2
fi

cd "$(dirname "$0")/../.."

resolve_repo_path() {
  local path="$1"
  if [[ "$path" = /* || "$path" =~ ^[A-Za-z]:[\\/] ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$PWD" "$path"
  fi
}

config_path="${GSTBK_NODE_CONFIG_PATH:-}"
if [[ -z "$config_path" && -n "${GSTBK_RUNTIME_CONFIG_DIR:-}" ]]; then
  config_path="$GSTBK_RUNTIME_CONFIG_DIR/node/node${node_id}/node_config.json"
fi
if [[ -n "$config_path" ]]; then
  config_path="$(resolve_repo_path "$config_path")"
  if [[ ! -f "$config_path" ]]; then
    echo "Node config path does not exist: $config_path" >&2
    exit 2
  fi
  export GSTBK_NODE_CONFIG_PATH="$config_path"
fi

node_info_dir="${GSTBK_NODE_INFO_DIR:-}"
if [[ -z "$node_info_dir" && -n "${GSTBK_RUNTIME_STATE_DIR:-}" ]]; then
  node_info_dir="$GSTBK_RUNTIME_STATE_DIR/node/node${node_id}/info"
fi
if [[ -z "$node_info_dir" ]]; then
  node_info_dir="crates/intergration_test/src/node/node${node_id}/info"
fi
node_info_dir="$(resolve_repo_path "$node_info_dir")"
mkdir -p "$node_info_dir"
export GSTBK_NODE_INFO_DIR="$node_info_dir"

entrypoint_mode="${GSTBK_ROLE_ENTRYPOINT_MODE:-bin}"
case "$entrypoint_mode" in
  bin)
    (
      cd crates/intergration_test
      cargo run --quiet --bin gstbk-node -- "$node_id"
    )
    ;;
  test)
    cargo test --package intergration_test --lib -- "node::node${node_id}::node${node_id}::test" --exact --nocapture
    ;;
  *)
    echo "Unsupported GSTBK_ROLE_ENTRYPOINT_MODE: $entrypoint_mode (expected bin or test)" >&2
    exit 2
    ;;
esac
