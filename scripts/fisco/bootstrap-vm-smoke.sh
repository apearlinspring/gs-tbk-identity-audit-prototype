#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEFAULT_PERSONAL_INFO_ADDRESS="0x6546c3571f17858ea45575e7c6457dad03e53dbb"
DEFAULT_SIGNATURE_ADDRESS="0xcceef68c9b4811b32c75df284a1396c7c5509561"

APP_DIR="${FISCO_JAVA_SDK_DIR:-$REPO_ROOT/chain-apps/fisco-bcos-java-sdk}"
CONFIG_PATH="${FISCO_CONFIG:-$APP_DIR/conf/config.toml}"
NODE_SDK_DIR="${FISCO_NODE_SDK_DIR:-/home/gstbk/fisco/nodes/127.0.0.1/sdk}"
CERT_DIR="${FISCO_CERT_DIR:-$APP_DIR/conf/sdk}"
ACCOUNT_DIR="${FISCO_ACCOUNT_DIR:-$APP_DIR/conf/accounts}"
GROUP="${FISCO_GROUP:-group0}"
PEERS="${FISCO_PEERS:-127.0.0.1:20200,127.0.0.1:20201}"
CONSOLE_DIR="${FISCO_CONSOLE_DIR:-/home/gstbk/fisco/console}"
NODE_DIR="${FISCO_NODE_DIR:-/home/gstbk/fisco/nodes/127.0.0.1}"
CHECK_PORTS="${FISCO_CHECK_PORTS:-20200 20201 30300 30301}"
ENV_FILE="${FISCO_ENV_OUTPUT:-$REPO_ROOT/.env.fisco.generated}"
CONTRACT_MODE="${FISCO_CONTRACT_MODE:-reuse}"
PREPARE_MODE="${FISCO_PREPARE_MODE:-auto}"
SMOKE_MODE="${GSTBK_BOOTSTRAP_SMOKE:-none}"
USERS="${GSTBK_BOOTSTRAP_USERS:-2}"
NODES="${GSTBK_BOOTSTRAP_NODES:-4}"
TIMEOUT_SECONDS="${GSTBK_BOOTSTRAP_TIMEOUT_SECONDS:-300}"
E2E_RUNTIME_DIR="${GSTBK_E2E_RUNTIME_DIR:-/tmp/gstbk-e2e-vm-smoke}"
SERVICE_RUNTIME_DIR="${GSTBK_SERVICE_RUNTIME_DIR:-/tmp/gstbk-service-vm-smoke}"
SERVICE_HOLD_SECONDS="${GSTBK_BOOTSTRAP_SERVICE_HOLD_SECONDS:-5}"
STRICT_SECRETS=0

PERSONAL_INFO_ADDRESS="${GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS:-$DEFAULT_PERSONAL_INFO_ADDRESS}"
SIGNATURE_ADDRESS="${GSTBK_SIGNATURE_CONTRACT_ADDRESS:-$DEFAULT_SIGNATURE_ADDRESS}"
SMOKE_COMMAND="not run"
SERVICE_CLEANUP_NEEDED=0

usage() {
    cat <<'EOF'
Usage: bash scripts/fisco/bootstrap-vm-smoke.sh [options]

Prepares the Java SDK config, runs FISCO doctor, reuses or deploys contracts,
validates .env.fisco.generated, and optionally runs E2E or service smoke.

Defaults target the gstbk VM baseline and do not rebuild or clear chain data.

Options:
  --prepare-mode <force|auto|skip>       SDK config preparation mode. Default: auto.
  --contract-mode <reuse|deploy|auto>    Contract mode passed to deploy-contracts.sh. Default: reuse.
  --smoke <none|e2e|service>             Optional smoke after doctor/reuse. Default: none.
  --app-dir <dir>                        Java SDK app directory.
  --config <path>                        FISCO SDK config.toml path.
  --node-sdk-dir <dir>                   Source node sdk directory.
  --cert-dir <dir>                       Destination SDK certificate directory.
  --account-dir <dir>                    Account directory referenced by config.toml.
  --group <group>                        FISCO group name. Default: group0.
  --peers <csv>                          Peer endpoints for prepare-sdk-conf.sh.
  --console-dir <dir>                    FISCO console directory.
  --node-dir <dir>                       FISCO node directory.
  --ports "20200 20201 ..."              Ports expected by doctor.
  --output <path>                        Generated env file path.
  --personal-info-address <address>      PersonalInfo address for reuse/auto mode.
  --signature-address <address>          Signature address for reuse/auto mode.
  --users <count>                        User count for smoke. Default: 2.
  --nodes <count>                        Node count for smoke. Default: 4.
  --timeout-seconds <seconds>            E2E wait timeout. Default: 300.
  --e2e-runtime-dir <path>               E2E runtime dir. Default: /tmp/gstbk-e2e-vm-smoke.
  --service-runtime-dir <path>           Service runtime dir. Default: /tmp/gstbk-service-vm-smoke.
  --service-hold-seconds <seconds>       Delay between service status and stop. Default: 5.
  --strict-secrets                       Pass strict sensitive config checks to doctor.
  -h, --help                             Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prepare-mode)
            PREPARE_MODE="$2"
            shift 2
            ;;
        --contract-mode)
            CONTRACT_MODE="$2"
            shift 2
            ;;
        --smoke)
            SMOKE_MODE="$2"
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
        --node-sdk-dir)
            NODE_SDK_DIR="$2"
            shift 2
            ;;
        --cert-dir)
            CERT_DIR="$2"
            shift 2
            ;;
        --account-dir)
            ACCOUNT_DIR="$2"
            shift 2
            ;;
        --group)
            GROUP="$2"
            shift 2
            ;;
        --peers)
            PEERS="$2"
            shift 2
            ;;
        --console-dir)
            CONSOLE_DIR="$2"
            shift 2
            ;;
        --node-dir)
            NODE_DIR="$2"
            shift 2
            ;;
        --ports)
            CHECK_PORTS="$2"
            shift 2
            ;;
        --output)
            ENV_FILE="$2"
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
        --users)
            USERS="$2"
            shift 2
            ;;
        --nodes)
            NODES="$2"
            shift 2
            ;;
        --timeout-seconds)
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        --e2e-runtime-dir)
            E2E_RUNTIME_DIR="$2"
            shift 2
            ;;
        --service-runtime-dir)
            SERVICE_RUNTIME_DIR="$2"
            shift 2
            ;;
        --service-hold-seconds)
            SERVICE_HOLD_SECONDS="$2"
            shift 2
            ;;
        --strict-secrets)
            STRICT_SECRETS=1
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

is_uint() {
    [[ "$1" =~ ^[0-9]+$ ]]
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
    is_address "$1" && ! is_zero_address "$1"
}

join_command() {
    printf '%q ' "$@"
}

require_uint_range() {
    local value="$1"
    local min="$2"
    local max="$3"
    local label="$4"
    if ! is_uint "$value" || [[ "$value" -lt "$min" || "$value" -gt "$max" ]]; then
        echo "$label must be $min..$max: $value" >&2
        exit 2
    fi
}

case "$PREPARE_MODE" in
    force|auto|skip) ;;
    *)
        echo "Unsupported prepare mode: $PREPARE_MODE" >&2
        exit 2
        ;;
esac

case "$CONTRACT_MODE" in
    reuse|deploy|auto) ;;
    *)
        echo "Unsupported contract mode: $CONTRACT_MODE" >&2
        exit 2
        ;;
esac

case "$SMOKE_MODE" in
    none|e2e|service) ;;
    *)
        echo "Unsupported smoke mode: $SMOKE_MODE" >&2
        exit 2
        ;;
esac

if [[ "$CONTRACT_MODE" == "deploy" ]]; then
    PERSONAL_INFO_ADDRESS=""
    SIGNATURE_ADDRESS=""
fi

require_uint_range "$USERS" 1 6 "users"
require_uint_range "$NODES" 1 4 "nodes"
require_uint_range "$TIMEOUT_SECONDS" 1 86400 "timeout seconds"
require_uint_range "$SERVICE_HOLD_SECONDS" 0 86400 "service hold seconds"

APP_DIR="$(abs_path "$APP_DIR" "$REPO_ROOT")"
CONFIG_PATH="$(abs_path "$CONFIG_PATH" "$REPO_ROOT")"
NODE_SDK_DIR="$(abs_path "$NODE_SDK_DIR" "$REPO_ROOT")"
CERT_DIR="$(abs_path "$CERT_DIR" "$REPO_ROOT")"
ACCOUNT_DIR="$(abs_path "$ACCOUNT_DIR" "$REPO_ROOT")"
CONSOLE_DIR="$(abs_path "$CONSOLE_DIR" "$REPO_ROOT")"
NODE_DIR="$(abs_path "$NODE_DIR" "$REPO_ROOT")"
ENV_FILE="$(abs_path "$ENV_FILE" "$REPO_ROOT")"
E2E_RUNTIME_DIR="$(abs_path "$E2E_RUNTIME_DIR" "$REPO_ROOT")"
SERVICE_RUNTIME_DIR="$(abs_path "$SERVICE_RUNTIME_DIR" "$REPO_ROOT")"

cleanup_service() {
    if [[ "$SERVICE_CLEANUP_NEEDED" -eq 1 ]]; then
        echo "[INFO] stopping service smoke roles from $SERVICE_RUNTIME_DIR"
        GSTBK_SERVICE_RUNTIME_DIR="$SERVICE_RUNTIME_DIR" \
            bash "$REPO_ROOT/scripts/run-local/gstbk-service.sh" stop all || true
        SERVICE_CLEANUP_NEEDED=0
    fi
}

trap cleanup_service EXIT

run_prepare_sdk_conf() {
    case "$PREPARE_MODE" in
        skip)
            echo "[INFO] Skipping SDK config preparation by request."
            return
            ;;
        auto)
            if [[ -f "$CONFIG_PATH" && -d "$CERT_DIR" ]]; then
                echo "[INFO] SDK config and certificate dir already exist; auto prepare skipped."
                return
            fi
            ;;
    esac

    local -a args=(
        --node-sdk-dir "$NODE_SDK_DIR"
        --app-dir "$APP_DIR"
        --config-out "$CONFIG_PATH"
        --cert-dir "$CERT_DIR"
        --account-dir "$ACCOUNT_DIR"
        --group "$GROUP"
        --peers "$PEERS"
        --force
    )

    echo "[RUN] bash scripts/fisco/prepare-sdk-conf.sh ${args[*]}"
    bash "$SCRIPT_DIR/prepare-sdk-conf.sh" "${args[@]}"
}

run_doctor() {
    local allow_missing="$1"
    local -a args=(
        --app-dir "$APP_DIR"
        --config "$CONFIG_PATH"
        --group "$GROUP"
        --console-dir "$CONSOLE_DIR"
        --node-dir "$NODE_DIR"
        --ports "$CHECK_PORTS"
    )

    if [[ "$allow_missing" == "true" ]]; then
        args+=(--allow-missing-contract-addresses)
    fi
    if [[ "$STRICT_SECRETS" -eq 1 ]]; then
        args+=(--strict-secrets)
    fi
    if [[ -n "$PERSONAL_INFO_ADDRESS" ]]; then
        args+=(--personal-info-address "$PERSONAL_INFO_ADDRESS")
    fi
    if [[ -n "$SIGNATURE_ADDRESS" ]]; then
        args+=(--signature-address "$SIGNATURE_ADDRESS")
    fi

    echo "[RUN] bash scripts/fisco/doctor.sh ${args[*]}"
    FISCO_CONFIG="$CONFIG_PATH" \
    FISCO_GROUP="$GROUP" \
    FISCO_CONSOLE_DIR="$CONSOLE_DIR" \
    GRADLE_BIN="${GRADLE_BIN:-}" \
        bash "$SCRIPT_DIR/doctor.sh" "${args[@]}"
}

run_deploy_contracts() {
    local -a args=(
        --mode "$CONTRACT_MODE"
        --app-dir "$APP_DIR"
        --config "$CONFIG_PATH"
        --group "$GROUP"
        --output "$ENV_FILE"
    )

    if [[ "$CONTRACT_MODE" != "deploy" ]]; then
        if [[ -n "$PERSONAL_INFO_ADDRESS" ]]; then
            args+=(--personal-info-address "$PERSONAL_INFO_ADDRESS")
        fi
        if [[ -n "$SIGNATURE_ADDRESS" ]]; then
            args+=(--signature-address "$SIGNATURE_ADDRESS")
        fi
    fi

    echo "[RUN] bash scripts/fisco/deploy-contracts.sh ${args[*]}"
    FISCO_CONSOLE_DIR="$CONSOLE_DIR" \
    GRADLE_BIN="${GRADLE_BIN:-}" \
        bash "$SCRIPT_DIR/deploy-contracts.sh" "${args[@]}"
}

validate_generated_env() {
    local failures=0

    if [[ ! -f "$ENV_FILE" ]]; then
        echo "[FAIL] generated env file not found: $ENV_FILE" >&2
        exit 1
    fi

    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a

    CONFIG_PATH="${FISCO_CONFIG:-}"
    GROUP="${FISCO_GROUP:-}"
    APP_DIR="${GSTBK_PERSONAL_INFO_APP_DIR:-}"
    PERSONAL_INFO_ADDRESS="${GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS:-}"
    SIGNATURE_ADDRESS="${GSTBK_SIGNATURE_CONTRACT_ADDRESS:-}"
    CONSOLE_DIR="${FISCO_CONSOLE_DIR:-$CONSOLE_DIR}"

    if [[ -z "${FISCO_CONFIG:-}" ]]; then
        echo "[FAIL] .env.fisco.generated is missing FISCO_CONFIG" >&2
        failures=$((failures + 1))
    elif [[ ! -f "$FISCO_CONFIG" ]]; then
        echo "[FAIL] FISCO_CONFIG does not exist: $FISCO_CONFIG" >&2
        failures=$((failures + 1))
    fi

    if [[ -z "${FISCO_GROUP:-}" ]]; then
        echo "[FAIL] .env.fisco.generated is missing FISCO_GROUP" >&2
        failures=$((failures + 1))
    fi

    if [[ -z "${GSTBK_PERSONAL_INFO_APP_DIR:-}" || ! -f "${GSTBK_PERSONAL_INFO_APP_DIR:-}/info_run.sh" ]]; then
        echo "[FAIL] .env.fisco.generated has invalid GSTBK_PERSONAL_INFO_APP_DIR" >&2
        failures=$((failures + 1))
    fi

    if [[ -z "${GSTBK_SIGNATURE_APP_DIR:-}" || ! -f "${GSTBK_SIGNATURE_APP_DIR:-}/signature_run.sh" ]]; then
        echo "[FAIL] .env.fisco.generated has invalid GSTBK_SIGNATURE_APP_DIR" >&2
        failures=$((failures + 1))
    fi

    if ! is_valid_nonzero_address "${GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS:-}"; then
        echo "[FAIL] .env.fisco.generated has invalid GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" >&2
        failures=$((failures + 1))
    fi

    if ! is_valid_nonzero_address "${GSTBK_SIGNATURE_CONTRACT_ADDRESS:-}"; then
        echo "[FAIL] .env.fisco.generated has invalid GSTBK_SIGNATURE_CONTRACT_ADDRESS" >&2
        failures=$((failures + 1))
    fi

    if [[ "$failures" -gt 0 ]]; then
        exit 1
    fi

    echo "[OK] generated env validated: $ENV_FILE"
}

chain_version() {
    if [[ -n "${FISCO_CHAIN_VERSION:-}" ]]; then
        printf '%s\n' "$FISCO_CHAIN_VERSION"
        return
    fi

    local binary=""
    binary="$(find "$NODE_DIR" -maxdepth 3 -type f -name fisco-bcos -perm -111 -print -quit 2>/dev/null || true)"
    if [[ -z "$binary" ]]; then
        printf 'unknown\n'
        return
    fi

    local output=""
    output="$("$binary" -v 2>&1 | sed -n '1p' || true)"
    if [[ -z "$output" ]]; then
        output="$("$binary" --version 2>&1 | sed -n '1p' || true)"
    fi
    printf '%s\n' "${output:-unknown}"
}

current_block_number() {
    local output value
    if [[ -z "${GSTBK_PERSONAL_INFO_APP_DIR:-}" || ! -f "$GSTBK_PERSONAL_INFO_APP_DIR/info_run.sh" ]]; then
        printf 'unknown\n'
        return
    fi

    if output="$(FISCO_CONFIG="$FISCO_CONFIG" FISCO_GROUP="$FISCO_GROUP" FISCO_CONSOLE_DIR="${FISCO_CONSOLE_DIR:-}" GRADLE_BIN="${GRADLE_BIN:-}" bash "$GSTBK_PERSONAL_INFO_APP_DIR/info_run.sh" blockNumber 2>&1)"; then
        value="$(printf '%s\n' "$output" | awk '/blockNumber/ { print $2; exit }')"
        printf '%s\n' "${value:-unknown}"
    else
        printf 'unknown\n'
    fi
}

run_e2e_smoke() {
    export LD_LIBRARY_PATH="$REPO_ROOT/crates/cl_encrypt:${LD_LIBRARY_PATH:-}"
    local -a cmd=(
        bash "$REPO_ROOT/scripts/run-local/run-e2e.sh"
        --users "$USERS"
        --nodes "$NODES"
        --runtime-dir "$E2E_RUNTIME_DIR"
        --reuse-chain
        --contract-addresses-from-env
        --timeout-seconds "$TIMEOUT_SECONDS"
    )
    SMOKE_COMMAND="$(join_command "${cmd[@]}")"
    echo "[RUN] $SMOKE_COMMAND"
    "${cmd[@]}"
}

run_service_smoke() {
    local service_command_prefix
    service_command_prefix="GSTBK_SERVICE_RUNTIME_DIR=$SERVICE_RUNTIME_DIR"
    SMOKE_COMMAND="$service_command_prefix bash scripts/run-local/gstbk-service.sh start all; status all; stop all"
    SERVICE_CLEANUP_NEEDED=1

    echo "[RUN] $service_command_prefix bash scripts/run-local/gstbk-service.sh start all"
    GSTBK_SERVICE_RUNTIME_DIR="$SERVICE_RUNTIME_DIR" \
    GSTBK_SERVICE_NODES="$NODES" \
    GSTBK_SERVICE_USERS="$USERS" \
        bash "$REPO_ROOT/scripts/run-local/gstbk-service.sh" start all

    echo "[RUN] $service_command_prefix bash scripts/run-local/gstbk-service.sh status all"
    GSTBK_SERVICE_RUNTIME_DIR="$SERVICE_RUNTIME_DIR" \
    GSTBK_SERVICE_NODES="$NODES" \
    GSTBK_SERVICE_USERS="$USERS" \
        bash "$REPO_ROOT/scripts/run-local/gstbk-service.sh" status all

    if [[ "$SERVICE_HOLD_SECONDS" -gt 0 ]]; then
        sleep "$SERVICE_HOLD_SECONDS"
    fi

    echo "[RUN] $service_command_prefix bash scripts/run-local/gstbk-service.sh stop all"
    GSTBK_SERVICE_RUNTIME_DIR="$SERVICE_RUNTIME_DIR" \
    GSTBK_SERVICE_NODES="$NODES" \
    GSTBK_SERVICE_USERS="$USERS" \
        bash "$REPO_ROOT/scripts/run-local/gstbk-service.sh" stop all
    SERVICE_CLEANUP_NEEDED=0
}

run_smoke() {
    case "$SMOKE_MODE" in
        none)
            SMOKE_COMMAND="not run; use --smoke e2e or --smoke service"
            echo "[INFO] Smoke run skipped."
            ;;
        e2e)
            run_e2e_smoke
            ;;
        service)
            run_service_smoke
            ;;
    esac
}

print_summary() {
    local version block node_end user_end
    version="$(chain_version)"
    block="$(current_block_number)"
    node_end=$((50001 + NODES - 1))
    user_end=$((60001 + USERS - 1))

    cat <<EOF
[SUMMARY] bootstrap-vm-smoke completed.
[SUMMARY] chainVersion: $version
[SUMMARY] group: ${FISCO_GROUP:-$GROUP}
[SUMMARY] fiscoNodePorts: $CHECK_PORTS
[SUMMARY] rolePorts: proxy 50000, node 50001-$node_end, user 60001-$user_end
[SUMMARY] personalInfoAddress: ${GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS:-$PERSONAL_INFO_ADDRESS}
[SUMMARY] signatureAddress: ${GSTBK_SIGNATURE_CONTRACT_ADDRESS:-$SIGNATURE_ADDRESS}
[SUMMARY] blockNumber: $block
[SUMMARY] envFile: $ENV_FILE
[SUMMARY] smoke: $SMOKE_MODE
[SUMMARY] runCommand: $SMOKE_COMMAND
EOF
}

cd "$REPO_ROOT"

echo "[INFO] Repository: $REPO_ROOT"
echo "[INFO] Prepare mode: $PREPARE_MODE"
echo "[INFO] Contract mode: $CONTRACT_MODE"
echo "[INFO] Smoke mode: $SMOKE_MODE"

run_prepare_sdk_conf
run_doctor true
run_deploy_contracts
validate_generated_env

PERSONAL_INFO_ADDRESS="${GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS:-$PERSONAL_INFO_ADDRESS}"
SIGNATURE_ADDRESS="${GSTBK_SIGNATURE_CONTRACT_ADDRESS:-$SIGNATURE_ADDRESS}"
CONFIG_PATH="${FISCO_CONFIG:-$CONFIG_PATH}"
GROUP="${FISCO_GROUP:-$GROUP}"
APP_DIR="${GSTBK_PERSONAL_INFO_APP_DIR:-$APP_DIR}"
CONSOLE_DIR="${FISCO_CONSOLE_DIR:-$CONSOLE_DIR}"

run_doctor false
run_smoke
print_summary
