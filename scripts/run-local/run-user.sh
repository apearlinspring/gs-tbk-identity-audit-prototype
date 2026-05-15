#!/usr/bin/env bash
set -euo pipefail

user_id="${1:-}"
if [[ ! "$user_id" =~ ^[1-6]$ ]]; then
  echo "Usage: bash scripts/run-local/run-user.sh <1|2|3|4|5|6>" >&2
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

config_path="${GSTBK_USER_CONFIG_PATH:-}"
if [[ -z "$config_path" && -n "${GSTBK_RUNTIME_CONFIG_DIR:-}" ]]; then
  config_path="$GSTBK_RUNTIME_CONFIG_DIR/user/user${user_id}/user_config.json"
fi
if [[ -n "$config_path" ]]; then
  config_path="$(resolve_repo_path "$config_path")"
  if [[ ! -f "$config_path" ]]; then
    echo "User config path does not exist: $config_path" >&2
    exit 2
  fi
  export GSTBK_USER_CONFIG_PATH="$config_path"
fi

user_info_dir="${GSTBK_USER_INFO_DIR:-}"
if [[ -z "$user_info_dir" && -n "${GSTBK_RUNTIME_STATE_DIR:-}" ]]; then
  user_info_dir="$GSTBK_RUNTIME_STATE_DIR/user/user${user_id}/info"
fi
if [[ -z "$user_info_dir" ]]; then
  user_info_dir="crates/intergration_test/src/user/user${user_id}/info"
fi
user_info_dir="$(resolve_repo_path "$user_info_dir")"
mkdir -p "$user_info_dir"
export GSTBK_USER_INFO_DIR="$user_info_dir"

if [[ -n "${GSTBK_PERSONAL_INFO_PAYLOAD_PATH:-}" ]]; then
  if [[ ! -f "$GSTBK_PERSONAL_INFO_PAYLOAD_PATH" ]]; then
    echo "GSTBK_PERSONAL_INFO_PAYLOAD_PATH does not exist: $GSTBK_PERSONAL_INFO_PAYLOAD_PATH" >&2
    exit 2
  fi
  cp "$GSTBK_PERSONAL_INFO_PAYLOAD_PATH" "$user_info_dir/personal_info.json"
fi

entrypoint_mode="${GSTBK_ROLE_ENTRYPOINT_MODE:-bin}"
case "$entrypoint_mode" in
  bin)
    (
      cd crates/intergration_test
      cargo run --quiet --bin gstbk-user -- "$user_id"
    )
    ;;
  test)
    cargo test --package intergration_test --lib -- "user::user${user_id}::user${user_id}::test" --exact --nocapture
    ;;
  *)
    echo "Unsupported GSTBK_ROLE_ENTRYPOINT_MODE: $entrypoint_mode (expected bin or test)" >&2
    exit 2
    ;;
esac
