#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP_DIR="${FISCO_JAVA_SDK_DIR:-$REPO_ROOT/chain-apps/fisco-bcos-java-sdk}"
NODE_SDK_DIR="${FISCO_NODE_SDK_DIR:-/home/gstbk/fisco/nodes/127.0.0.1/sdk}"
CONFIG_OUT="${FISCO_CONFIG:-$APP_DIR/conf/config.toml}"
CERT_DIR="${FISCO_CERT_DIR:-$APP_DIR/conf/sdk}"
ACCOUNT_DIR="${FISCO_ACCOUNT_DIR:-$APP_DIR/conf/accounts}"
GROUP="${FISCO_GROUP:-group0}"
PEERS="${FISCO_PEERS:-127.0.0.1:20200,127.0.0.1:20201}"
DRY_RUN=0
FORCE=0

usage() {
    cat <<'EOF'
Usage: bash scripts/fisco/prepare-sdk-conf.sh [options]

Copies SDK certificates from a FISCO node sdk directory and writes an ignored
Java SDK config.toml for chain-apps/fisco-bcos-java-sdk.

Options:
  --node-sdk-dir <dir>      Source node sdk directory.
  --app-dir <dir>           Java SDK app directory.
  --config-out <path>       Output config.toml path.
  --cert-dir <dir>          Destination SDK certificate directory.
  --account-dir <dir>       Account directory referenced by config.toml.
  --group <group>           FISCO group name, defaults to group0.
  --peers <csv>             Peer endpoints, for example 127.0.0.1:20200,127.0.0.1:20201.
  --dry-run                 Print actions without copying or writing files.
  --force                   Overwrite existing config.toml.
  -h, --help                Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --node-sdk-dir)
            NODE_SDK_DIR="$2"
            shift 2
            ;;
        --app-dir)
            APP_DIR="$2"
            shift 2
            ;;
        --config-out)
            CONFIG_OUT="$2"
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
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --force)
            FORCE=1
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

APP_DIR="$(abs_path "$APP_DIR" "$REPO_ROOT")"
NODE_SDK_DIR="$(abs_path "$NODE_SDK_DIR" "$REPO_ROOT")"
CONFIG_OUT="$(abs_path "$CONFIG_OUT" "$REPO_ROOT")"
CERT_DIR="$(abs_path "$CERT_DIR" "$REPO_ROOT")"
ACCOUNT_DIR="$(abs_path "$ACCOUNT_DIR" "$REPO_ROOT")"

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

path_for_config() {
    local path="$1"
    local app="$APP_DIR"
    case "$path" in
        "$app"/*)
            printf '%s\n' "${path#"$app"/}"
            ;;
        *)
            printf '%s\n' "$path"
            ;;
    esac
}

toml_peers() {
    local csv="$1"
    local result=""
    local item
    IFS=',' read -r -a peer_items <<< "$csv"
    for item in "${peer_items[@]}"; do
        item="$(trim "$item")"
        [[ -z "$item" ]] && continue
        if [[ -n "$result" ]]; then
            result+=", "
        fi
        result+="\"$item\""
    done
    if [[ -z "$result" ]]; then
        echo "No peers were provided." >&2
        exit 2
    fi
    printf '[%s]\n' "$result"
}

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

assert_not_tracked_secret_path() {
    local path="$1"
    local rel
    if ! rel="$(relative_to_repo "$path")"; then
        return
    fi

    if [[ "$rel" == *.example ]]; then
        return
    fi

    if git -C "$REPO_ROOT" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
        echo "Refusing to write sensitive material to tracked Git path: $rel" >&2
        echo "Use an ignored path such as chain-apps/fisco-bcos-java-sdk/conf/config.toml." >&2
        exit 1
    fi
}

plan() {
    printf '[PLAN] %s\n' "$1"
}

run_or_plan() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        plan "$1"
    else
        eval "$2"
    fi
}

if [[ ! -d "$APP_DIR" ]]; then
    echo "Java SDK app directory not found: $APP_DIR" >&2
    exit 1
fi

if [[ ! -d "$NODE_SDK_DIR" ]]; then
    echo "Node SDK directory not found: $NODE_SDK_DIR" >&2
    exit 1
fi

if [[ -e "$CONFIG_OUT" && "$FORCE" -ne 1 ]]; then
    echo "Config already exists: $CONFIG_OUT" >&2
    echo "Pass --force to overwrite it." >&2
    exit 1
fi

assert_not_tracked_secret_path "$CONFIG_OUT"
assert_not_tracked_secret_path "$CERT_DIR"
assert_not_tracked_secret_path "$ACCOUNT_DIR"

mapfile -t SDK_FILES < <(find "$NODE_SDK_DIR" -maxdepth 1 -type f | sort)
if [[ "${#SDK_FILES[@]}" -eq 0 ]]; then
    echo "No SDK files found under: $NODE_SDK_DIR" >&2
    exit 1
fi

echo "[WARN] SDK certificates, private keys, accounts, and generated config.toml are sensitive."
echo "[WARN] Keep them on the VM or another local secure path; do not commit them."
echo "[INFO] Java SDK app: $APP_DIR"
echo "[INFO] Source SDK dir: $NODE_SDK_DIR"
echo "[INFO] Config output: $CONFIG_OUT"
echo "[INFO] Certificate dir: $CERT_DIR"
echo "[INFO] Account dir: $ACCOUNT_DIR"
echo "[INFO] Group: $GROUP"
echo "[INFO] Peers: $PEERS"

if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "create directory $CERT_DIR with mode 700"
    plan "create directory $ACCOUNT_DIR with mode 700"
else
    mkdir -p "$CERT_DIR" "$ACCOUNT_DIR" "$(dirname "$CONFIG_OUT")"
    chmod 700 "$CERT_DIR" "$ACCOUNT_DIR"
    printf '[OK] restricted directory permissions to 700: %s\n' "$CERT_DIR"
    printf '[OK] restricted directory permissions to 700: %s\n' "$ACCOUNT_DIR"
fi

for source_file in "${SDK_FILES[@]}"; do
    target_file="$CERT_DIR/$(basename "$source_file")"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        plan "copy $source_file -> $target_file"
    else
        install -m 600 "$source_file" "$target_file"
        printf '[OK] copied %s -> %s\n' "$source_file" "$target_file"
    fi
done

CERT_PATH_FOR_CONFIG="$(path_for_config "$CERT_DIR")"
ACCOUNT_PATH_FOR_CONFIG="$(path_for_config "$ACCOUNT_DIR")"
PEERS_FOR_CONFIG="$(toml_peers "$PEERS")"

if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "write config.toml to $CONFIG_OUT"
else
    cat > "$CONFIG_OUT" <<EOF
[cryptoMaterial]
certPath = "$CERT_PATH_FOR_CONFIG"
disableSsl = "false"
useSMCrypto = "false"

[network]
messageTimeout = "10000"
defaultGroup = "$GROUP"
peers = $PEERS_FOR_CONFIG

[account]
keyStoreDir = "$ACCOUNT_PATH_FOR_CONFIG"
accountFileFormat = "pem"

[threadPool]
# threadPoolSize = "16"
EOF
    chmod 600 "$CONFIG_OUT"
    printf '[OK] wrote %s\n' "$CONFIG_OUT"
fi

echo "[SUMMARY] SDK configuration preparation completed."
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[SUMMARY] dry-run only; no files were changed."
fi
