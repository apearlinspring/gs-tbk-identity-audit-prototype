#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

resolve_repo_path() {
  local path="$1"
  if [[ "$path" = /* || "$path" =~ ^[A-Za-z]:[\\/] ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$PWD" "$path"
  fi
}

config_path="${GSTBK_PROXY_CONFIG_PATH:-}"
if [[ -z "$config_path" && -n "${GSTBK_RUNTIME_CONFIG_DIR:-}" ]]; then
  config_path="$GSTBK_RUNTIME_CONFIG_DIR/proxy/proxy_config.json"
fi
if [[ -n "$config_path" ]]; then
  config_path="$(resolve_repo_path "$config_path")"
  if [[ ! -f "$config_path" ]]; then
    echo "Proxy config path does not exist: $config_path" >&2
    exit 2
  fi
  export GSTBK_PROXY_CONFIG_PATH="$config_path"
fi

entrypoint_mode="${GSTBK_ROLE_ENTRYPOINT_MODE:-bin}"
case "$entrypoint_mode" in
  bin)
    (
      cd crates/intergration_test
      cargo run --quiet --bin gstbk-proxy
    )
    ;;
  test)
    cargo test --package intergration_test --lib -- proxy::proxy_node::test --exact --nocapture
    ;;
  *)
    echo "Unsupported GSTBK_ROLE_ENTRYPOINT_MODE: $entrypoint_mode (expected bin or test)" >&2
    exit 2
    ;;
esac
