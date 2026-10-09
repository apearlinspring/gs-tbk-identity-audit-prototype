#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
shift || true
cd "$(dirname "$0")/../.."
export GSTBK_RUNTIME_DIR="${GSTBK_RUNTIME_DIR:-$PWD/runtime-state}"
mkdir -p "$GSTBK_RUNTIME_DIR"
export GSTBK_CL_KEYPAIR_PATH="${GSTBK_CL_KEYPAIR_PATH:-$GSTBK_RUNTIME_DIR/cl_keypair.json}"
export LD_LIBRARY_PATH="$PWD/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"

case "$mode" in
  keygen)
    if [ "$#" -eq 0 ]; then
      set -- --output "$GSTBK_CL_KEYPAIR_PATH"
    fi
    cargo run --quiet --package id_info_process --bin id_info_process -- keygen "$@"
    ;;
  enc|enc-prove)
    if [ "$#" -eq 0 ]; then
      set -- \
        --input "${GSTBK_ID_INFO_INPUT_PATH:-$PWD/examples/id-info/user1.json}" \
        --output "${GSTBK_ID_INFO_OUTPUT_PATH:-$GSTBK_RUNTIME_DIR/block_personal_info.json}"
    fi
    cargo run --quiet --package id_info_process --bin id_info_process -- enc "$@"
    ;;
  verify|decrypt)
    if [ "$#" -eq 0 ]; then
      set -- --input "${GSTBK_ID_INFO_OUTPUT_PATH:-$GSTBK_RUNTIME_DIR/block_personal_info.json}"
    fi
    cargo run --quiet --package id_info_process --bin id_info_process -- verify "$@"
    ;;
  *)
    echo "Usage: bash scripts/run-local/run-id-info.sh <keygen|enc|verify> [--input <json>] [--output <json>]" >&2
    exit 2
    ;;
esac
