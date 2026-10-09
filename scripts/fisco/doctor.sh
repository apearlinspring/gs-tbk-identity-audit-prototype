#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP_DIR="${FISCO_JAVA_SDK_DIR:-$REPO_ROOT/chain-apps/fisco-bcos-java-sdk}"
CONFIG_PATH="${FISCO_CONFIG:-$APP_DIR/conf/config.toml}"
GROUP="${FISCO_GROUP:-group0}"
CONSOLE_DIR="${FISCO_CONSOLE_DIR:-/home/gstbk/fisco/console}"
NODE_DIR="${FISCO_NODE_DIR:-/home/gstbk/fisco/nodes/127.0.0.1}"
CERT_DIR="${FISCO_CERT_DIR:-}"
CHECK_PORTS="${FISCO_CHECK_PORTS:-20200 20201 30300 30301}"
PERSONAL_INFO_ADDRESS="${GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS:-}"
SIGNATURE_ADDRESS="${GSTBK_SIGNATURE_CONTRACT_ADDRESS:-}"
ALLOW_MISSING_CONTRACTS=0
STRICT_SECRETS="${FISCO_DOCTOR_STRICT_SECRETS:-0}"

FAILURES=0
WARNINGS=0

usage() {
    cat <<'EOF'
Usage: bash scripts/fisco/doctor.sh [options]

Checks the local FISCO BCOS node, Java SDK configuration, certificates,
ports, group connectivity, blockNumber, GSTBK contract address variables,
and sensitive config guardrails.

Options:
  --app-dir <dir>                       Java SDK app directory.
  --config <path>                       FISCO SDK config.toml path.
  --group <group>                       FISCO group name, defaults to group0.
  --console-dir <dir>                   FISCO console directory.
  --node-dir <dir>                      FISCO node directory.
  --cert-dir <dir>                      SDK certificate directory.
  --ports "20200 20201 ..."             Ports expected to be listening.
  --personal-info-address <address>     PersonalInfo contract address.
  --signature-address <address>         Signature contract address.
  --allow-missing-contract-addresses    Warn instead of failing when addresses are unset.
  --strict-secrets                      Fail on broad sensitive file permissions or missing ignore rules.
  -h, --help                            Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
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
        --console-dir)
            CONSOLE_DIR="$2"
            shift 2
            ;;
        --node-dir)
            NODE_DIR="$2"
            shift 2
            ;;
        --cert-dir)
            CERT_DIR="$2"
            shift 2
            ;;
        --ports)
            CHECK_PORTS="$2"
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
        --allow-missing-contract-addresses)
            ALLOW_MISSING_CONTRACTS=1
            shift
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

if [[ "$APP_DIR" != /* ]]; then
    APP_DIR="$REPO_ROOT/$APP_DIR"
fi
if [[ "$CONFIG_PATH" != /* ]]; then
    CONFIG_PATH="$REPO_ROOT/$CONFIG_PATH"
fi
if [[ -n "$CERT_DIR" && "$CERT_DIR" != /* ]]; then
    CERT_DIR="$REPO_ROOT/$CERT_DIR"
fi
case "$(printf '%s' "$STRICT_SECRETS" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on)
        STRICT_SECRETS=1
        ;;
    *)
        STRICT_SECRETS=0
        ;;
esac

ok() {
    printf '[OK]   %s\n' "$1"
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    printf '[WARN] %s\n' "$1"
}

fail() {
    FAILURES=$((FAILURES + 1))
    printf '[FAIL] %s\n' "$1"
}

info() {
    printf '[INFO] %s\n' "$1"
}

sensitive_warn() {
    if [[ "$STRICT_SECRETS" -eq 1 ]]; then
        fail "$1"
    else
        warn "$1"
    fi
}

first_line() {
    sed -n '1p'
}

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

stat_mode() {
    local path="$1"
    local mode=""
    if mode="$(stat -c '%a' "$path" 2>/dev/null)"; then
        :
    elif mode="$(stat -f '%Lp' "$path" 2>/dev/null)"; then
        :
    else
        return 1
    fi

    mode="${mode: -3}"
    if [[ ! "$mode" =~ ^[0-7]{3}$ ]]; then
        return 1
    fi
    printf '%s\n' "$mode"
}

check_permission_profile() {
    local path="$1"
    local label="$2"
    local profile="$3"

    if [[ ! -e "$path" ]]; then
        return
    fi

    local mode
    if ! mode="$(stat_mode "$path")"; then
        warn "Cannot inspect permissions for $label: $path"
        return
    fi

    local mode_value
    mode_value=$((8#$mode))

    case "$profile" in
        config_file)
            if (( (mode_value & 0007) != 0 || (mode_value & 0020) != 0 )); then
                sensitive_warn "$label permissions are $mode; recommend 600 or 640: $path"
            else
                ok "$label permissions look restrictive ($mode): $path"
            fi
            ;;
        sensitive_dir)
            if (( (mode_value & 0007) != 0 || (mode_value & 0020) != 0 )); then
                sensitive_warn "$label permissions are $mode; recommend 700 or 750: $path"
            else
                ok "$label permissions look restrictive ($mode): $path"
            fi
            ;;
        private_file)
            if (( (mode_value & 0077) != 0 )); then
                sensitive_warn "$label permissions are $mode; recommend 600: $path"
            else
                ok "$label permissions look restrictive ($mode): $path"
            fi
            ;;
        *)
            warn "Unknown permission profile $profile for $path"
            ;;
    esac
}

check_git_ignore_path() {
    local path="$1"
    if git -C "$REPO_ROOT" check-ignore -q -- "$path"; then
        ok "Git ignore covers sensitive path: $path"
    else
        sensitive_warn "Git ignore does not cover common sensitive path: $path"
    fi
}

check_git_ignore_guardrails() {
    if ! command -v git >/dev/null 2>&1; then
        warn "git is not available; cannot check sensitive path ignore coverage."
        return
    fi
    if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        warn "Repository root is not a Git worktree; cannot check ignore coverage."
        return
    fi

    local paths=(
        ".env"
        ".env.local"
        ".env.fisco.generated"
        ".env.fisco.generated.local"
        "logs/example.log"
        "runtime-logs/example.log"
        "runtime-state/example.json"
        "state/example.json"
        "cl_keypair.json"
        "wallet.json"
        "account.json"
        "accounts.json"
        "private_key.pem"
        "secret.key"
        "chain-apps/fisco-bcos-java-sdk/conf/config.toml"
        "chain-apps/fisco-bcos-java-sdk/conf/local.toml"
        "chain-apps/fisco-bcos-java-sdk/conf/sdk/"
        "chain-apps/fisco-bcos-java-sdk/conf/sdk/sdk.key"
        "chain-apps/fisco-bcos-java-sdk/conf/accounts/"
        "chain-apps/fisco-bcos-java-sdk/conf/accounts/account.pem"
        "chain-apps/fisco-bcos-java-sdk/conf/wallet/"
        "chain-apps/fisco-bcos-java-sdk/conf/wallet/key.pem"
        "chain-apps/fisco-bcos-java-sdk/conf/keystore/"
        "chain-apps/fisco-bcos-java-sdk/conf/keystore/key.keystore"
    )

    local path
    for path in "${paths[@]}"; do
        check_git_ignore_path "$path"
    done
}

check_sensitive_file_permissions_in_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        return
    fi

    local item
    while IFS= read -r -d '' item; do
        local base
        local lowered
        base="$(basename "$item")"
        lowered="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
        case "$lowered" in
            *.example|*.sample|readme.md)
                ;;
            config.toml|*.toml)
                check_permission_profile "$item" "Config file" "config_file"
                ;;
            *.key|*.pem|*.p12|*.pfx|*.jks|*.keystore|*private*|*secret*|*wallet*|*account*)
                check_permission_profile "$item" "Sensitive file" "private_file"
                ;;
        esac
    done < <(find "$dir" -maxdepth 2 -type f -print0 2>/dev/null)
}

check_sensitive_inventory() {
    info "Checking sensitive config inventory and Git ignore guardrails."
    check_git_ignore_guardrails

    local default_config="$APP_DIR/conf/config.toml"
    if [[ -f "$CONFIG_PATH" ]]; then
        ok "FISCO_CONFIG target exists: $CONFIG_PATH"
        check_permission_profile "$CONFIG_PATH" "FISCO_CONFIG" "config_file"
    else
        info "FISCO_CONFIG target is not present: $CONFIG_PATH"
    fi

    if [[ "$CONFIG_PATH" != "$default_config" ]]; then
        if [[ -f "$default_config" ]]; then
            ok "Default Java SDK config exists: $default_config"
            check_permission_profile "$default_config" "Default Java SDK config" "config_file"
        else
            info "Default Java SDK config is not present: $default_config"
        fi
    fi

    local sensitive_dirs=(
        "$APP_DIR/conf/sdk"
        "$APP_DIR/conf/accounts"
        "$APP_DIR/conf/account"
        "$APP_DIR/conf/wallet"
        "$APP_DIR/conf/wallets"
        "$APP_DIR/conf/keystore"
        "$APP_DIR/conf/keystores"
    )

    local dir
    for dir in "${sensitive_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            ok "Sensitive directory exists: $dir"
            check_permission_profile "$dir" "Sensitive directory" "sensitive_dir"
            check_sensitive_file_permissions_in_dir "$dir"
        else
            info "Sensitive directory is not present: $dir"
        fi
    done
}

toml_value() {
    local key="$1"
    local file="$2"
    awk -F '=' -v key="$key" '
        $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            value=$2
            sub(/#.*/, "", value)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "$file"
}

resolve_cert_dir() {
    if [[ -n "$CERT_DIR" ]]; then
        printf '%s\n' "$CERT_DIR"
        return
    fi

    if [[ -f "$CONFIG_PATH" ]]; then
        local cert_path
        cert_path="$(toml_value "certPath" "$CONFIG_PATH")"
        if [[ -n "$cert_path" ]]; then
            if [[ "$cert_path" == /* ]]; then
                printf '%s\n' "$cert_path"
            elif [[ -d "$APP_DIR/$cert_path" || "$cert_path" == conf/* ]]; then
                printf '%s\n' "$APP_DIR/$cert_path"
            else
                printf '%s\n' "$(dirname "$CONFIG_PATH")/$cert_path"
            fi
            return
        fi
    fi

    printf '%s\n' "$APP_DIR/conf/sdk"
}

is_address() {
    [[ "$1" =~ ^0x[0-9a-fA-F]{40}$ ]]
}

is_zero_address() {
    local lowered
    lowered="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    [[ "$lowered" == "0x0000000000000000000000000000000000000000" ]]
}

check_contract_address() {
    local name="$1"
    local env_name="$2"
    local value="$3"

    if [[ -z "$value" ]]; then
        if [[ "$ALLOW_MISSING_CONTRACTS" -eq 1 ]]; then
            warn "$env_name is not set; $name address check skipped for pre-deploy diagnostics."
        else
            fail "$env_name is not set."
        fi
        return
    fi

    if ! is_address "$value"; then
        fail "$env_name is not a 40-byte hex address: $value"
        return
    fi

    if is_zero_address "$value"; then
        fail "$env_name is the all-zero placeholder address."
        return
    fi

    ok "$env_name is set to $value"
}

port_is_listening() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -ltn | awk -v suffix=":$port" '$4 ~ suffix "$" { found=1 } END { exit found ? 0 : 1 }'
        return $?
    fi
    if command -v netstat >/dev/null 2>&1; then
        netstat -ltn 2>/dev/null | awk -v suffix=":$port" '$4 ~ suffix "$" { found=1 } END { exit found ? 0 : 1 }'
        return $?
    fi
    if command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
        return $?
    fi
    return 2
}

print_header() {
    cat <<EOF
FISCO BCOS environment doctor
Repository: $REPO_ROOT
Java SDK:   $APP_DIR
Config:     $CONFIG_PATH
Group:      $GROUP
Console:    $CONSOLE_DIR
Node dir:   $NODE_DIR
Ports:      $CHECK_PORTS
Strict:     sensitive guardrails $(if [[ "$STRICT_SECRETS" -eq 1 ]]; then printf 'enabled'; else printf 'warn-only'; fi)
EOF
}

check_java() {
    if ! command -v java >/dev/null 2>&1; then
        fail "java is not available on PATH."
        return
    fi
    local version
    version="$(java -version 2>&1 | first_line)"
    ok "Java available: $version"
}

check_gradle() {
    if [[ -n "${GRADLE_BIN:-}" ]]; then
        if [[ -x "$GRADLE_BIN" ]]; then
            ok "Gradle available through GRADLE_BIN=$GRADLE_BIN"
        else
            fail "GRADLE_BIN is set but not executable: $GRADLE_BIN"
        fi
        return
    fi

    if [[ -x "$APP_DIR/gradlew" ]]; then
        ok "Gradle wrapper is executable: $APP_DIR/gradlew"
    elif [[ -f "$APP_DIR/gradlew" ]]; then
        ok "Gradle wrapper exists and will be invoked through bash: $APP_DIR/gradlew"
    elif command -v gradle >/dev/null 2>&1; then
        ok "Gradle available on PATH: $(command -v gradle)"
    else
        fail "No Gradle wrapper, GRADLE_BIN, or gradle command found."
    fi
}

check_console() {
    if [[ ! -d "$CONSOLE_DIR" ]]; then
        fail "FISCO console directory not found: $CONSOLE_DIR"
        return
    fi
    if [[ ! -f "$CONSOLE_DIR/start.sh" ]]; then
        fail "FISCO console start.sh not found under: $CONSOLE_DIR"
        return
    fi
    if [[ -d "$CONSOLE_DIR/lib" ]]; then
        ok "FISCO console found with lib directory: $CONSOLE_DIR"
    else
        warn "FISCO console found but lib directory is missing: $CONSOLE_DIR"
    fi
}

check_config_and_certs() {
    if [[ ! -d "$APP_DIR" ]]; then
        fail "Java SDK app directory not found: $APP_DIR"
        return
    fi
    if [[ ! -x "$APP_DIR/info_run.sh" && ! -f "$APP_DIR/info_run.sh" ]]; then
        fail "info_run.sh not found under Java SDK app: $APP_DIR"
    else
        ok "info_run.sh found."
    fi
    if [[ ! -x "$APP_DIR/signature_run.sh" && ! -f "$APP_DIR/signature_run.sh" ]]; then
        fail "signature_run.sh not found under Java SDK app: $APP_DIR"
    else
        ok "signature_run.sh found."
    fi

    if [[ ! -f "$CONFIG_PATH" ]]; then
        fail "FISCO SDK config not found: $CONFIG_PATH"
        return
    fi
    ok "FISCO SDK config exists: $CONFIG_PATH"
    check_permission_profile "$CONFIG_PATH" "FISCO SDK config" "config_file"

    local config_group
    config_group="$(toml_value "defaultGroup" "$CONFIG_PATH")"
    if [[ -n "$config_group" && "$config_group" != "$GROUP" ]]; then
        warn "Config defaultGroup is $config_group, but doctor will check group $GROUP."
    else
        ok "FISCO group selected: $GROUP"
    fi

    CERT_DIR="$(resolve_cert_dir)"
    if [[ ! -d "$CERT_DIR" ]]; then
        fail "SDK certificate directory not found: $CERT_DIR"
        return
    fi
    ok "SDK certificate directory exists: $CERT_DIR"
    check_permission_profile "$CERT_DIR" "SDK certificate directory" "sensitive_dir"

    local missing_cert=0
    for cert_file in ca.crt sdk.crt sdk.key; do
        if [[ -f "$CERT_DIR/$cert_file" ]]; then
            ok "Certificate material present: $CERT_DIR/$cert_file"
            if [[ "$cert_file" == "sdk.key" ]]; then
                check_permission_profile "$CERT_DIR/$cert_file" "SDK private key" "private_file"
            fi
        else
            missing_cert=1
            fail "Expected certificate material missing: $CERT_DIR/$cert_file"
        fi
    done

    if [[ "$missing_cert" -eq 0 ]]; then
        info "Certificate files are sensitive and must stay out of Git."
    fi

    local account_dir
    account_dir="$(toml_value "keyStoreDir" "$CONFIG_PATH")"
    if [[ -n "$account_dir" ]]; then
        if [[ "$account_dir" != /* ]]; then
            account_dir="$APP_DIR/$account_dir"
        fi
        if [[ -d "$account_dir" ]]; then
            ok "Account directory exists: $account_dir"
            check_permission_profile "$account_dir" "Account directory" "sensitive_dir"
            check_sensitive_file_permissions_in_dir "$account_dir"
        else
            warn "Account directory not found: $account_dir"
        fi
    fi
}

check_node_processes() {
    if [[ -d "$NODE_DIR" ]]; then
        ok "FISCO node directory exists: $NODE_DIR"
    else
        fail "FISCO node directory not found: $NODE_DIR"
    fi

    local processes=""
    if command -v pgrep >/dev/null 2>&1; then
        processes="$(pgrep -fa '(^|[[:space:]/])fisco-bcos([[:space:]]|$)' || true)"
    else
        processes="$(ps -ef | awk '/(^|[[:space:]\/])fisco-bcos([[:space:]]|$)/ { print }')"
    fi

    if [[ -n "$processes" ]]; then
        local count
        count="$(printf '%s\n' "$processes" | awk 'NF { count++ } END { print count + 0 }')"
        ok "fisco-bcos process count: $count"
        printf '%s\n' "$processes" | sed 's/^/[INFO] process: /'
    else
        fail "No fisco-bcos processes found."
    fi
}

check_ports() {
    local port
    for port in $CHECK_PORTS; do
        if port_is_listening "$port"; then
            ok "Port $port is listening."
        else
            local rc=$?
            if [[ "$rc" -eq 2 ]]; then
                warn "No ss/netstat/lsof available; cannot check port $port."
            else
                fail "Port $port is not listening."
            fi
        fi
    done
}

check_block_number() {
    if [[ ! -f "$APP_DIR/info_run.sh" ]]; then
        fail "Cannot check blockNumber because info_run.sh is missing."
        return
    fi
    if [[ ! -f "$CONFIG_PATH" ]]; then
        fail "Cannot check blockNumber because FISCO_CONFIG is missing."
        return
    fi

    local output
    if output="$(FISCO_CONFIG="$CONFIG_PATH" FISCO_GROUP="$GROUP" FISCO_CONSOLE_DIR="$CONSOLE_DIR" GRADLE_BIN="${GRADLE_BIN:-}" bash "$APP_DIR/info_run.sh" blockNumber 2>&1)"; then
        local block_number
        block_number="$(printf '%s\n' "$output" | awk '/blockNumber/ { print $2; exit }')"
        if [[ -n "$block_number" ]]; then
            ok "Java SDK blockNumber for $GROUP: $block_number"
        else
            warn "blockNumber command succeeded but output was not parsed."
            printf '%s\n' "$output" | sed 's/^/[INFO] blockNumber output: /'
        fi
    else
        fail "Java SDK blockNumber command failed."
        printf '%s\n' "$output" | sed -n '1,20s/^/[INFO] blockNumber output: /p'
    fi
}

print_header
check_sensitive_inventory
check_java
check_gradle
check_console
check_config_and_certs
check_node_processes
check_ports
check_contract_address "PersonalInfo" "GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" "$PERSONAL_INFO_ADDRESS"
check_contract_address "Signature" "GSTBK_SIGNATURE_CONTRACT_ADDRESS" "$SIGNATURE_ADDRESS"
check_block_number

if [[ "$FAILURES" -gt 0 ]]; then
    printf '[SUMMARY] doctor failed: %d failure(s), %d warning(s).\n' "$FAILURES" "$WARNINGS"
    exit 1
fi

printf '[SUMMARY] doctor passed: %d warning(s).\n' "$WARNINGS"
