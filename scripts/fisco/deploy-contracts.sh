#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP_DIR="${FISCO_JAVA_SDK_DIR:-$REPO_ROOT/chain-apps/fisco-bcos-java-sdk}"
CONFIG_PATH="${FISCO_CONFIG:-$APP_DIR/conf/config.toml}"
GROUP="${FISCO_GROUP:-group0}"
CONSOLE_DIR="${FISCO_CONSOLE_DIR:-/home/gstbk/fisco/console}"
OUTPUT_FILE="${FISCO_ENV_OUTPUT:-$REPO_ROOT/.env.fisco.generated}"
MODE="auto"
PERSONAL_INFO_ADDRESS="${GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS:-}"
SIGNATURE_ADDRESS="${GSTBK_SIGNATURE_CONTRACT_ADDRESS:-}"
DRY_RUN=0
SKIP_PROBE=0

usage() {
    cat <<'EOF'
Usage: bash scripts/fisco/deploy-contracts.sh [options]

Deploys or reuses PersonalInfo and Signature contracts through the existing
Java SDK scripts, then writes an ignored .env.fisco.generated file.

Modes:
  auto    Reuse valid supplied addresses; deploy only missing addresses. Default.
  reuse   Require supplied addresses and only probe/rewrite env output.
  deploy  Deploy both contracts and write the new addresses.

Options:
  --mode <auto|reuse|deploy>             Deployment mode.
  --app-dir <dir>                        Java SDK app directory.
  --config <path>                        FISCO SDK config.toml path.
  --group <group>                        FISCO group name, defaults to group0.
  --output <path>                        Generated env file path.
  --personal-info-address <address>      Reuse PersonalInfo address.
  --signature-address <address>          Reuse Signature address.
  --skip-probe                           Do not run select probes for reused addresses.
  --dry-run                              Print actions without deploying or writing.
  -h, --help                             Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --app-dir)
            APP_DIR="$2"
            shift 2
            ;;
        --config)
            CONFIG_PATH="$2"
            shift 2
            ;;
        --group)
            GROUP="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --personal-info-address)
            PERSONAL_INFO_ADDRESS="$2"
            shift 2
            ;;
        --signature-address)
            SIGNATURE_ADDRESS="$2"
            shift 2
            ;;
        --skip-probe)
            SKIP_PROBE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$MODE" in
    auto|reuse|deploy)
        ;;
    *)
        echo "Unsupported mode: $MODE" >&2
        usage >&2
        exit 2
        ;;
esac

abs_path() {
    local path="$1"
    local base="${2:-$PWD}"
    if [[ "$path" == /* ]]; then
        if command -v realpath >/dev/null 2>&1; then
            realpath -m "$path"
        else
            printf '%s\n' "$path"
        fi
    else
        if command -v realpath >/dev/null 2>&1; then
            realpath -m "$base/$path"
        else
            printf '%s\n' "$base/$path"
        fi
    fi
}

APP_DIR="$(abs_path "$APP_DIR" "$REPO_ROOT")"
CONFIG_PATH="$(abs_path "$CONFIG_PATH" "$REPO_ROOT")"
OUTPUT_FILE="$(abs_path "$OUTPUT_FILE" "$REPO_ROOT")"

relative_to_repo() {
    local path="$1"
    case "$path" in
        "$REPO_ROOT"/*)
            printf '%s\n' "${path#"$REPO_ROOT"/}"
            ;;
        *)
            return 1
            ;;
    esac
}

assert_output_not_tracked() {
    local rel
    if ! rel="$(relative_to_repo "$OUTPUT_FILE")"; then
        return
    fi
    if [[ "$rel" == *.example ]]; then
        return
    fi
    if git -C "$REPO_ROOT" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
        echo "Refusing to write generated env to tracked Git path: $rel" >&2
        exit 1
    fi
}

shell_quote() {
    local value="$1"
    printf "'%s'" "$(printf '%s' "$value" | sed "s/'/'\\\\''/g")"
}

is_address() {
    [[ "$1" =~ ^0x[0-9a-fA-F]{40}$ ]]
}

is_zero_address() {
    local lowered
    lowered="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    [[ "$lowered" == "0x0000000000000000000000000000000000000000" ]]
}

is_valid_nonzero_address() {
    local value="$1"
    is_address "$value" && ! is_zero_address "$value"
}

require_file() {
    local label="$1"
    local path="$2"
    if [[ ! -f "$path" ]]; then
        echo "$label not found: $path" >&2
        exit 1
    fi
}

run_sdk() {
    local script="$1"
    shift
    FISCO_CONFIG="$CONFIG_PATH" \
    FISCO_GROUP="$GROUP" \
    FISCO_CONSOLE_DIR="$CONSOLE_DIR" \
    GRADLE_BIN="${GRADLE_BIN:-}" \
        bash "$script" "$@"
}

parse_contract_address() {
    awk '/contractAddress/ { print $2; exit }'
}

parse_block_number() {
    awk '/blockNumber/ { print $2; exit }'
}

deploy_one() {
    local label="$1"
    local script="$2"
    local output address block_number

    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[PLAN] deploy %s with %s deploy\n' "$label" "$script" >&2
        printf '0x0000000000000000000000000000000000000000|dry-run\n'
        return
    fi

    echo "[INFO] Deploying $label through $script deploy" >&2
    if ! output="$(run_sdk "$script" deploy 2>&1)"; then
        echo "[FAIL] $label deploy failed." >&2
        printf '%s\n' "$output" | sed -n '1,40s/^/[INFO] deploy output: /p' >&2
        exit 1
    fi

    address="$(printf '%s\n' "$output" | parse_contract_address)"
    block_number="$(printf '%s\n' "$output" | parse_block_number)"
    if ! is_valid_nonzero_address "$address"; then
        echo "[FAIL] Could not parse a valid $label address from deploy output." >&2
        printf '%s\n' "$output" | sed -n '1,40s/^/[INFO] deploy output: /p' >&2
        exit 1
    fi

    echo "[OK] $label deployed at $address" >&2
    if [[ -n "$block_number" ]]; then
        echo "[OK] $label deploy blockNumber $block_number" >&2
    fi
    printf '%s|%s\n' "$address" "${block_number:-unknown}"
}

probe_one() {
    local label="$1"
    local script="$2"
    local address="$3"
    local output

    if [[ "$SKIP_PROBE" -eq 1 ]]; then
        echo "[WARN] Skipping $label reuse probe by request."
        return
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[PLAN] probe %s at %s with select __gstbk_probe__\n' "$label" "$address"
        return
    fi

    if ! output="$(run_sdk "$script" select "$address" "__gstbk_probe__" 2>&1)"; then
        echo "[FAIL] $label reuse probe failed for $address." >&2
        printf '%s\n' "$output" | sed -n '1,40s/^/[INFO] probe output: /p' >&2
        exit 1
    fi
    echo "[OK] $label reuse probe succeeded for $address"
}

block_number() {
    local script="$1"
    local output value
    if output="$(run_sdk "$script" blockNumber 2>&1)"; then
        value="$(printf '%s\n' "$output" | parse_block_number)"
        printf '%s\n' "${value:-unknown}"
    else
        printf 'unknown\n'
    fi
}

write_env_file() {
    local personal_address="$1"
    local signature_address="$2"
    local personal_mode="$3"
    local signature_mode="$4"
    local personal_block="$5"
    local signature_block="$6"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[PLAN] write generated env file to $OUTPUT_FILE"
        return
    fi

    mkdir -p "$(dirname "$OUTPUT_FILE")"
    cat > "$OUTPUT_FILE" <<EOF
# Generated by scripts/fisco/deploy-contracts.sh on $(date -u '+%Y-%m-%dT%H:%M:%SZ').
# This file contains local FISCO BCOS contract addresses and paths only.
# It is ignored by Git; do not commit real chain configuration or credentials.

export FISCO_CONFIG=$(shell_quote "$CONFIG_PATH")
export FISCO_GROUP=$(shell_quote "$GROUP")
export FISCO_CONSOLE_DIR=$(shell_quote "$CONSOLE_DIR")
EOF
    if [[ -n "${GRADLE_BIN:-}" ]]; then
        printf 'export GRADLE_BIN=%s\n' "$(shell_quote "$GRADLE_BIN")" >> "$OUTPUT_FILE"
    fi
    cat >> "$OUTPUT_FILE" <<EOF
export GSTBK_PERSONAL_INFO_APP_DIR=$(shell_quote "$APP_DIR")
export GSTBK_SIGNATURE_APP_DIR=$(shell_quote "$APP_DIR")
export GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS=$(shell_quote "$personal_address")
export GSTBK_SIGNATURE_CONTRACT_ADDRESS=$(shell_quote "$signature_address")

# PersonalInfo decision: $personal_mode, blockNumber: $personal_block
# Signature decision: $signature_mode, blockNumber: $signature_block
EOF
    chmod 600 "$OUTPUT_FILE"
    echo "[OK] wrote generated env file: $OUTPUT_FILE"
}

validate_generated_env_file() {
    local personal_address="$1"
    local signature_address="$2"
    local failures=0

    if [[ "$DRY_RUN" -eq 1 ]]; then
        return
    fi

    if [[ ! -f "$OUTPUT_FILE" ]]; then
        echo "[FAIL] Generated env file was not written: $OUTPUT_FILE" >&2
        exit 1
    fi

    (
        set -euo pipefail
        # shellcheck disable=SC1090
        . "$OUTPUT_FILE"

        if [[ -z "${FISCO_CONFIG:-}" ]]; then
            echo "[FAIL] .env.fisco.generated is missing FISCO_CONFIG" >&2
            exit 10
        fi
        if [[ ! -f "$FISCO_CONFIG" ]]; then
            echo "[FAIL] FISCO_CONFIG does not exist: $FISCO_CONFIG" >&2
            exit 10
        fi
        if [[ -z "${FISCO_GROUP:-}" ]]; then
            echo "[FAIL] .env.fisco.generated is missing FISCO_GROUP" >&2
            exit 10
        fi
        if [[ -z "${GSTBK_PERSONAL_INFO_APP_DIR:-}" || ! -f "$GSTBK_PERSONAL_INFO_APP_DIR/info_run.sh" ]]; then
            echo "[FAIL] .env.fisco.generated has invalid GSTBK_PERSONAL_INFO_APP_DIR" >&2
            exit 10
        fi
        if [[ -z "${GSTBK_SIGNATURE_APP_DIR:-}" || ! -f "$GSTBK_SIGNATURE_APP_DIR/signature_run.sh" ]]; then
            echo "[FAIL] .env.fisco.generated has invalid GSTBK_SIGNATURE_APP_DIR" >&2
            exit 10
        fi
        if ! is_valid_nonzero_address "${GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS:-}"; then
            echo "[FAIL] .env.fisco.generated has invalid GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" >&2
            exit 10
        fi
        if ! is_valid_nonzero_address "${GSTBK_SIGNATURE_CONTRACT_ADDRESS:-}"; then
            echo "[FAIL] .env.fisco.generated has invalid GSTBK_SIGNATURE_CONTRACT_ADDRESS" >&2
            exit 10
        fi
    ) || failures=$((failures + 1))

    if ! is_valid_nonzero_address "$personal_address"; then
        echo "[FAIL] Internal PersonalInfo address is invalid before env validation" >&2
        failures=$((failures + 1))
    fi
    if ! is_valid_nonzero_address "$signature_address"; then
        echo "[FAIL] Internal Signature address is invalid before env validation" >&2
        failures=$((failures + 1))
    fi

    if [[ "$failures" -gt 0 ]]; then
        exit 1
    fi

    echo "[OK] generated env fields validated."
}

assert_output_not_tracked
require_file "FISCO SDK config" "$CONFIG_PATH"
require_file "PersonalInfo runner" "$APP_DIR/info_run.sh"
require_file "Signature runner" "$APP_DIR/signature_run.sh"

echo "[INFO] Mode: $MODE"
echo "[INFO] Java SDK app: $APP_DIR"
echo "[INFO] FISCO config: $CONFIG_PATH"
echo "[INFO] FISCO group: $GROUP"
echo "[INFO] FISCO console: $CONSOLE_DIR"
echo "[INFO] Output env: $OUTPUT_FILE"

PERSONAL_DECISION="reuse"
SIGNATURE_DECISION="reuse"
PERSONAL_BLOCK="unknown"
SIGNATURE_BLOCK="unknown"

if [[ "$MODE" == "deploy" ]]; then
    PERSONAL_INFO_ADDRESS=""
    SIGNATURE_ADDRESS=""
fi

if [[ -n "$PERSONAL_INFO_ADDRESS" ]] && ! is_valid_nonzero_address "$PERSONAL_INFO_ADDRESS"; then
    echo "Invalid PersonalInfo address: $PERSONAL_INFO_ADDRESS" >&2
    exit 1
fi
if [[ -n "$SIGNATURE_ADDRESS" ]] && ! is_valid_nonzero_address "$SIGNATURE_ADDRESS"; then
    echo "Invalid Signature address: $SIGNATURE_ADDRESS" >&2
    exit 1
fi

if [[ "$MODE" == "reuse" ]]; then
    if [[ -z "$PERSONAL_INFO_ADDRESS" || -z "$SIGNATURE_ADDRESS" ]]; then
        echo "Mode reuse requires both contract addresses." >&2
        exit 1
    fi
fi

if [[ -n "$PERSONAL_INFO_ADDRESS" ]]; then
    probe_one "PersonalInfo" "$APP_DIR/info_run.sh" "$PERSONAL_INFO_ADDRESS"
    PERSONAL_BLOCK="$(block_number "$APP_DIR/info_run.sh")"
else
    result="$(deploy_one "PersonalInfo" "$APP_DIR/info_run.sh")"
    PERSONAL_INFO_ADDRESS="${result%%|*}"
    PERSONAL_BLOCK="${result#*|}"
    PERSONAL_DECISION="deploy"
fi

if [[ -n "$SIGNATURE_ADDRESS" ]]; then
    probe_one "Signature" "$APP_DIR/signature_run.sh" "$SIGNATURE_ADDRESS"
    SIGNATURE_BLOCK="$(block_number "$APP_DIR/signature_run.sh")"
else
    result="$(deploy_one "Signature" "$APP_DIR/signature_run.sh")"
    SIGNATURE_ADDRESS="${result%%|*}"
    SIGNATURE_BLOCK="${result#*|}"
    SIGNATURE_DECISION="deploy"
fi

write_env_file \
    "$PERSONAL_INFO_ADDRESS" \
    "$SIGNATURE_ADDRESS" \
    "$PERSONAL_DECISION" \
    "$SIGNATURE_DECISION" \
    "$PERSONAL_BLOCK" \
    "$SIGNATURE_BLOCK"
validate_generated_env_file "$PERSONAL_INFO_ADDRESS" "$SIGNATURE_ADDRESS"

echo "[SUMMARY] PersonalInfo $PERSONAL_DECISION: $PERSONAL_INFO_ADDRESS (blockNumber $PERSONAL_BLOCK)"
echo "[SUMMARY] Signature $SIGNATURE_DECISION: $SIGNATURE_ADDRESS (blockNumber $SIGNATURE_BLOCK)"
