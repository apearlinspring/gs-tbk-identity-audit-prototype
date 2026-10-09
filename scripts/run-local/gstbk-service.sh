#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/run-local/gstbk-service.sh <start|stop|status|restart|tail> <target> [id] [tail options]

Targets:
  proxy
  node <1|2|3|4>
  user <1|2|3|4|5|6>
  all

Tail options:
  -n, --lines <count>   Number of lines to show. Default: GSTBK_SERVICE_TAIL_LINES, then 80.
  -f, --follow          Follow the selected log after printing existing lines.

Environment:
  GSTBK_SERVICE_RUNTIME_DIR              Default: ./runtime-state/service-supervision
  GSTBK_SERVICE_NODES                    Default: 4
  GSTBK_SERVICE_USERS                    Default: 2
  GSTBK_SERVICE_HOST                     Default: 127.0.0.1
  GSTBK_SERVICE_LISTEN_HOST              Default: 0.0.0.0
  GSTBK_SERVICE_PROXY_PORT               Default: 50000
  GSTBK_SERVICE_NODE_PORT_START          Default: 50001
  GSTBK_SERVICE_USER_PORT_START          Default: 60001
  GSTBK_SERVICE_START_TIMEOUT_SECONDS    Default: 300
  GSTBK_SERVICE_FLOW_TIMEOUT_SECONDS     Default: 300
  GSTBK_SERVICE_STOP_TIMEOUT_SECONDS     Default: 20
  GSTBK_SERVICE_ROLE_ENTRYPOINT_MODE     Default: bin
EOF
}

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

resolve_repo_path() {
  local path="$1"
  if [[ "$path" = /* || "$path" =~ ^[A-Za-z]:[\\/] ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$repo_root" "$path"
  fi
}

runtime_root="$(resolve_repo_path "${GSTBK_SERVICE_RUNTIME_DIR:-runtime-state/service-supervision}")"
pid_dir="$runtime_root/pids"
runtime_log_dir="$runtime_root/runtime-logs"
runtime_config_dir="$(resolve_repo_path "${GSTBK_SERVICE_CONFIG_DIR:-$runtime_root/runtime-config}")"
runtime_state_dir="$(resolve_repo_path "${GSTBK_SERVICE_STATE_DIR:-$runtime_root/runtime-state}")"
identity_dir="$runtime_state_dir/identity"

service_nodes="${GSTBK_SERVICE_NODES:-4}"
service_users="${GSTBK_SERVICE_USERS:-2}"
service_host="${GSTBK_SERVICE_HOST:-127.0.0.1}"
service_listen_host="${GSTBK_SERVICE_LISTEN_HOST:-0.0.0.0}"
service_threshold="${GSTBK_SERVICE_THRESHOLD:-2}"
service_entrypoint_mode="${GSTBK_SERVICE_ROLE_ENTRYPOINT_MODE:-bin}"
proxy_port="${GSTBK_SERVICE_PROXY_PORT:-50000}"
node_port_start="${GSTBK_SERVICE_NODE_PORT_START:-50001}"
user_port_start="${GSTBK_SERVICE_USER_PORT_START:-60001}"
start_timeout_seconds="${GSTBK_SERVICE_START_TIMEOUT_SECONDS:-300}"
flow_timeout_seconds="${GSTBK_SERVICE_FLOW_TIMEOUT_SECONDS:-300}"
stop_timeout_seconds="${GSTBK_SERVICE_STOP_TIMEOUT_SECONDS:-20}"
tail_lines="${GSTBK_SERVICE_TAIL_LINES:-80}"
tail_follow="false"

library_path="$repo_root/crates/cl_encrypt"
if [ -n "${LD_LIBRARY_PATH:-}" ]; then
  library_path="$library_path:$LD_LIBRARY_PATH"
fi

ensure_runtime_dirs() {
  mkdir -p "$pid_dir" "$runtime_log_dir" "$runtime_config_dir" "$runtime_state_dir" "$identity_dir"
}

is_uint() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

validate_range() {
  local value="$1"
  local min="$2"
  local max="$3"
  local label="$4"
  if ! is_uint "$value" || [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
    echo "$label must be $min..$max: $value" >&2
    exit 2
  fi
}

role_name() {
  local kind="$1"
  local id="${2:-}"
  case "$kind" in
    proxy) printf 'proxy\n' ;;
    node) printf 'node%s\n' "$id" ;;
    user) printf 'user%s\n' "$id" ;;
    *) echo "Unknown role kind: $kind" >&2; exit 2 ;;
  esac
}

pid_file_for() {
  printf '%s/%s.pid\n' "$pid_dir" "$(role_name "$1" "${2:-}")"
}

log_file_for() {
  printf '%s/%s.log\n' "$runtime_log_dir" "$(role_name "$1" "${2:-}")"
}

command_file_for() {
  printf '%s/%s.command\n' "$runtime_log_dir" "$(role_name "$1" "${2:-}")"
}

role_port() {
  local kind="$1"
  local id="${2:-}"
  case "$kind" in
    proxy) printf '%s\n' "$proxy_port" ;;
    node) printf '%s\n' "$((node_port_start + id - 1))" ;;
    user) printf '%s\n' "$((user_port_start + id - 1))" ;;
    *) return 1 ;;
  esac
}

read_pid() {
  local pid_file="$1"
  if [ ! -f "$pid_file" ]; then
    return 1
  fi
  tr -d '[:space:]' <"$pid_file"
}

process_is_running() {
  local pid="$1"
  [ -n "$pid" ] && is_uint "$pid" && kill -0 "$pid" >/dev/null 2>&1
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

wait_for_port() {
  local kind="$1"
  local id="${2:-}"
  local pid="$3"
  local name port deadline log_file
  name="$(role_name "$kind" "$id")"
  port="$(role_port "$kind" "$id")"
  log_file="$(log_file_for "$kind" "$id")"
  deadline=$((SECONDS + start_timeout_seconds))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if port_is_listening "$port"; then
      echo "$name is listening on port $port"
      return 0
    fi
    if ! process_is_running "$pid"; then
      echo "$name exited before listening on port $port; see $log_file" >&2
      tail -n 80 "$log_file" >&2 || true
      return 1
    fi
    sleep 1
  done
  echo "Timed out waiting for $name on port $port; see $log_file" >&2
  return 1
}

wait_for_log() {
  local log_file="$1"
  local pattern="$2"
  local label="$3"
  local deadline
  deadline=$((SECONDS + flow_timeout_seconds))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if [ -f "$log_file" ] && grep -Fq "$pattern" "$log_file"; then
      echo "$label matched '$pattern'"
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for '$pattern' in $log_file" >&2
  return 1
}

render_runtime_config() {
  local nodes_count="$1"
  local users_count="$2"
  local render_log="$runtime_log_dir/render-configs.log"
  ensure_runtime_dirs

  if [ "${GSTBK_SERVICE_RENDER_CONFIGS:-1}" = "0" ]; then
    if [ ! -d "$runtime_config_dir" ]; then
      echo "GSTBK_SERVICE_RENDER_CONFIGS=0 but runtime config dir does not exist: $runtime_config_dir" >&2
      exit 2
    fi
    return
  fi

  bash scripts/run-local/render-configs.sh \
    --mode local \
    --host "$service_host" \
    --nodes "$nodes_count" \
    --users "$users_count" \
    --threshold "$service_threshold" \
    --proxy-port "$proxy_port" \
    --node-port-start "$node_port_start" \
    --user-port-start "$user_port_start" \
    --listen-host "$service_listen_host" \
    --user-name-prefix "${GSTBK_SERVICE_USER_NAME_PREFIX:-user}" \
    --user-name-suffix "${GSTBK_SERVICE_USER_NAME_SUFFIX:-_test_32}" \
    --output-dir "$runtime_config_dir" >"$render_log" 2>&1
}

ensure_identity_payload() {
  local user_id="$1"
  local explicit_payload user_payload_var input output key_log enc_log verify_log

  user_payload_var="GSTBK_USER${user_id}_PERSONAL_INFO_PAYLOAD_PATH"
  explicit_payload="$(printenv "$user_payload_var" || true)"
  if [ -z "$explicit_payload" ]; then
    explicit_payload="${GSTBK_PERSONAL_INFO_PAYLOAD_PATH:-}"
  fi
  if [ -n "$explicit_payload" ]; then
    if [ ! -f "$explicit_payload" ]; then
      echo "$user_payload_var/GSTBK_PERSONAL_INFO_PAYLOAD_PATH does not exist: $explicit_payload" >&2
      exit 2
    fi
    printf '%s\n' "$explicit_payload"
    return
  fi

  if [ "${GSTBK_SERVICE_GENERATE_IDENTITY:-1}" = "0" ]; then
    return
  fi

  input="$repo_root/examples/id-info/user${user_id}.json"
  if [ ! -f "$input" ]; then
    echo "No identity input sample for user${user_id}: $input" >&2
    echo "Start continues without GSTBK_PERSONAL_INFO_PAYLOAD_PATH; provide $user_payload_var for full chain registration." >&2
    return
  fi

  output="$identity_dir/user${user_id}-block-personal-info.json"
  key_log="$runtime_log_dir/id-info-keygen.log"
  enc_log="$runtime_log_dir/id-info-user${user_id}-enc.log"
  verify_log="$runtime_log_dir/id-info-user${user_id}-verify.log"

  if [ ! -f "$identity_dir/cl_keypair.json" ]; then
    GSTBK_RUNTIME_DIR="$runtime_state_dir" \
    GSTBK_CL_KEYPAIR_PATH="$identity_dir/cl_keypair.json" \
    LD_LIBRARY_PATH="$library_path" \
      bash scripts/run-local/run-id-info.sh keygen >"$key_log" 2>&1
  fi

  if [ ! -f "$output" ]; then
    GSTBK_RUNTIME_DIR="$runtime_state_dir" \
    GSTBK_CL_KEYPAIR_PATH="$identity_dir/cl_keypair.json" \
    GSTBK_ID_INFO_INPUT_PATH="$input" \
    GSTBK_ID_INFO_OUTPUT_PATH="$output" \
    LD_LIBRARY_PATH="$library_path" \
      bash scripts/run-local/run-id-info.sh enc >"$enc_log" 2>&1

    GSTBK_RUNTIME_DIR="$runtime_state_dir" \
    GSTBK_CL_KEYPAIR_PATH="$identity_dir/cl_keypair.json" \
    GSTBK_ID_INFO_OUTPUT_PATH="$output" \
    LD_LIBRARY_PATH="$library_path" \
      bash scripts/run-local/run-id-info.sh verify >"$verify_log" 2>&1
  fi

  printf '%s\n' "$output"
}

start_role() {
  local kind="$1"
  local id="${2:-}"
  local name pid_file log_file command_file existing_pid payload pid
  local -a launch_cmd

  ensure_runtime_dirs
  name="$(role_name "$kind" "$id")"
  pid_file="$(pid_file_for "$kind" "$id")"
  log_file="$(log_file_for "$kind" "$id")"
  command_file="$(command_file_for "$kind" "$id")"
  existing_pid="$(read_pid "$pid_file" || true)"

  if process_is_running "$existing_pid"; then
    echo "$name is already running with pid $existing_pid"
    return 0
  fi
  rm -f "$pid_file"
  if [ -f "$log_file" ]; then
    mv "$log_file" "$log_file.$(date -u +%Y%m%dT%H%M%SZ).previous"
  fi

  launch_cmd=(
    env
    -u GSTBK_PROXY_CONFIG_PATH
    -u GSTBK_NODE_CONFIG_PATH
    -u GSTBK_USER_CONFIG_PATH
    -u GSTBK_NODE_INFO_DIR
    -u GSTBK_USER_INFO_DIR
    -u GSTBK_PERSONAL_INFO_PAYLOAD_PATH
    "GSTBK_RUNTIME_CONFIG_DIR=$runtime_config_dir"
    "GSTBK_RUNTIME_STATE_DIR=$runtime_state_dir"
    "GSTBK_RUNTIME_DIR=$runtime_state_dir"
    "GSTBK_ROLE_ENTRYPOINT_MODE=$service_entrypoint_mode"
    "LD_LIBRARY_PATH=$library_path"
  )

  case "$kind" in
    proxy)
      launch_cmd+=(bash scripts/run-local/run-proxy.sh)
      ;;
    node)
      launch_cmd+=(bash scripts/run-local/run-node.sh "$id")
      ;;
    user)
      payload="$(ensure_identity_payload "$id")"
      if [ -n "$payload" ]; then
        launch_cmd+=("GSTBK_PERSONAL_INFO_PAYLOAD_PATH=$payload")
      fi
      launch_cmd+=(bash scripts/run-local/run-user.sh "$id")
      ;;
    *)
      echo "Unknown role kind: $kind" >&2
      exit 2
      ;;
  esac

  {
    printf '==== %s starting %s ====\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$name"
  } >>"$log_file"
  printf '%q ' "${launch_cmd[@]}" >"$command_file"
  printf '\n' >>"$command_file"

  if command -v setsid >/dev/null 2>&1; then
    # shellcheck disable=SC2016 # The inner Bash script expands $1/$@ after bash -c receives argv.
    setsid bash -c 'cd "$1" || exit 1; shift; exec "$@"' gstbk-service "$repo_root" "${launch_cmd[@]}" >>"$log_file" 2>&1 &
  else
    # shellcheck disable=SC2016 # The inner Bash script expands $1/$@ after bash -c receives argv.
    bash -c 'cd "$1" || exit 1; shift; exec "$@"' gstbk-service "$repo_root" "${launch_cmd[@]}" >>"$log_file" 2>&1 &
  fi

  pid="$!"
  printf '%s\n' "$pid" >"$pid_file"
  echo "$name started pid $pid log $log_file"
  wait_for_port "$kind" "$id" "$pid"
}

stop_role() {
  local kind="$1"
  local id="${2:-}"
  local name pid_file pid deadline
  name="$(role_name "$kind" "$id")"
  pid_file="$(pid_file_for "$kind" "$id")"
  pid="$(read_pid "$pid_file" || true)"

  if ! process_is_running "$pid"; then
    rm -f "$pid_file"
    echo "$name is stopped"
    return 0
  fi

  kill -TERM "-$pid" >/dev/null 2>&1 || kill -TERM "$pid" >/dev/null 2>&1 || true
  deadline=$((SECONDS + stop_timeout_seconds))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if ! process_is_running "$pid"; then
      rm -f "$pid_file"
      echo "$name stopped"
      return 0
    fi
    sleep 1
  done

  kill -KILL "-$pid" >/dev/null 2>&1 || kill -KILL "$pid" >/dev/null 2>&1 || true
  rm -f "$pid_file"
  echo "$name killed after timeout"
}

status_role() {
  local kind="$1"
  local id="${2:-}"
  local name pid_file pid state port listen_state log_file
  name="$(role_name "$kind" "$id")"
  pid_file="$(pid_file_for "$kind" "$id")"
  pid="$(read_pid "$pid_file" || true)"
  log_file="$(log_file_for "$kind" "$id")"
  port="$(role_port "$kind" "$id")"

  if process_is_running "$pid"; then
    state="running"
  elif [ -n "$pid" ]; then
    state="stale"
  else
    state="stopped"
  fi

  if port_is_listening "$port"; then
    listen_state="listen"
  else
    listen_state="-"
  fi

  printf '%-8s %-8s %-8s %-7s %s\n' "$name" "${pid:--}" "$state" "$listen_state:$port" "$log_file"
}

tail_role() {
  local kind="$1"
  local id="${2:-}"
  local name log_file
  name="$(role_name "$kind" "$id")"
  log_file="$(log_file_for "$kind" "$id")"
  if [ ! -f "$log_file" ]; then
    echo "No log file for $name: $log_file" >&2
    return 1
  fi
  echo "==> $log_file"
  if [ "$tail_follow" = "true" ]; then
    tail -n "$tail_lines" -f "$log_file"
  else
    tail -n "$tail_lines" "$log_file"
  fi
}

expanded_kinds=()
expanded_ids=()

append_role() {
  expanded_kinds+=("$1")
  expanded_ids+=("${2:-}")
}

expand_target() {
  local target="$1"
  local target_id="${2:-}"
  expanded_kinds=()
  expanded_ids=()

  validate_range "$service_nodes" 1 4 "GSTBK_SERVICE_NODES"
  validate_range "$service_users" 1 6 "GSTBK_SERVICE_USERS"

  case "$target" in
    proxy)
      if [ -n "$target_id" ]; then
        echo "proxy does not accept an id" >&2
        exit 2
      fi
      append_role proxy
      ;;
    node)
      validate_range "$target_id" 1 4 "node id"
      append_role node "$target_id"
      ;;
    user)
      validate_range "$target_id" 1 6 "user id"
      append_role user "$target_id"
      ;;
    all)
      if [ -n "$target_id" ]; then
        echo "all does not accept an id" >&2
        exit 2
      fi
      append_role proxy
      local index
      for index in $(seq 1 "$service_nodes"); do
        append_role node "$index"
      done
      for index in $(seq 1 "$service_users"); do
        append_role user "$index"
      done
      ;;
    *)
      echo "Unknown target: $target" >&2
      usage
      exit 2
      ;;
  esac
}

max_requested_node_count() {
  local max="$service_nodes"
  local index kind id
  for index in "${!expanded_kinds[@]}"; do
    kind="${expanded_kinds[$index]}"
    id="${expanded_ids[$index]}"
    if [ "$kind" = "node" ] && [ "$id" -gt "$max" ]; then
      max="$id"
    fi
  done
  printf '%s\n' "$max"
}

max_requested_user_count() {
  local max="$service_users"
  local index kind id
  for index in "${!expanded_kinds[@]}"; do
    kind="${expanded_kinds[$index]}"
    id="${expanded_ids[$index]}"
    if [ "$kind" = "user" ] && [ "$id" -gt "$max" ]; then
      max="$id"
    fi
  done
  printf '%s\n' "$max"
}

run_for_expanded_roles() {
  local action="$1"
  local index kind id has_proxy has_user waited_for_keygen
  case "$action" in
    start)
      render_runtime_config "$(max_requested_node_count)" "$(max_requested_user_count)"
      has_proxy="false"
      has_user="false"
      waited_for_keygen="false"
      for index in "${!expanded_kinds[@]}"; do
        kind="${expanded_kinds[$index]}"
        if [ "$kind" = "proxy" ]; then
          has_proxy="true"
        elif [ "$kind" = "user" ]; then
          has_user="true"
        fi
      done
      for index in "${!expanded_kinds[@]}"; do
        kind="${expanded_kinds[$index]}"
        id="${expanded_ids[$index]}"
        if [ "$kind" = "user" ] && [ "$has_proxy" = "true" ] && [ "$has_user" = "true" ] && [ "$waited_for_keygen" = "false" ] && [ "${GSTBK_SERVICE_WAIT_FOR_KEYGEN:-1}" != "0" ]; then
          wait_for_log "$(log_file_for proxy)" "Keygen phase is finished!" "proxy-keygen"
          waited_for_keygen="true"
        fi
        start_role "$kind" "$id"
      done
      ;;
    stop)
      for ((index=${#expanded_kinds[@]} - 1; index >= 0; index--)); do
        kind="${expanded_kinds[$index]}"
        id="${expanded_ids[$index]}"
        stop_role "$kind" "$id"
      done
      ;;
    status)
      ensure_runtime_dirs
      printf '%-8s %-8s %-8s %-7s %s\n' "ROLE" "PID" "STATE" "PORT" "LOG"
      for index in "${!expanded_kinds[@]}"; do
        kind="${expanded_kinds[$index]}"
        id="${expanded_ids[$index]}"
        status_role "$kind" "$id"
      done
      ;;
    tail)
      ensure_runtime_dirs
      for index in "${!expanded_kinds[@]}"; do
        kind="${expanded_kinds[$index]}"
        id="${expanded_ids[$index]}"
        tail_role "$kind" "$id"
      done
      ;;
    *)
      echo "Unknown action: $action" >&2
      exit 2
      ;;
  esac
}

command="${1:-}"
if [ -z "$command" ]; then
  usage
  exit 2
fi
case "$command" in
  -h|--help|help)
    usage
    exit 0
    ;;
esac
shift

target="${1:-}"
if [ -z "$target" ]; then
  usage
  exit 2
fi
shift

target_id=""
if [ "$target" = "node" ] || [ "$target" = "user" ]; then
  target_id="${1:-}"
  if [ -z "$target_id" ]; then
    usage
    exit 2
  fi
  shift
fi

case "$command" in
  start|stop|status|restart|tail) ;;
  *)
    echo "Unknown command: $command" >&2
    usage
    exit 2
    ;;
esac

if [ "$command" = "tail" ]; then
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -f|--follow)
        tail_follow="true"
        shift
        ;;
      -n|--lines)
        tail_lines="${2:?--lines requires a value}"
        shift 2
        ;;
      *)
        echo "Unknown tail option: $1" >&2
        usage
        exit 2
        ;;
    esac
  done
  validate_range "$tail_lines" 1 10000 "tail lines"
elif [ "$#" -gt 0 ]; then
  echo "Unexpected arguments: $*" >&2
  usage
  exit 2
fi

expand_target "$target" "$target_id"

case "$command" in
  restart)
    run_for_expanded_roles stop
    run_for_expanded_roles start
    ;;
  *)
    run_for_expanded_roles "$command"
    ;;
esac
