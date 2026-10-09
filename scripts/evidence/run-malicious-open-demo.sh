#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/evidence/run-malicious-open-demo.sh --manifest <manifest.json> [options]

Options:
  -m, --manifest <path>     run-e2e manifest JSON containing role logs and chain results.
  -o, --output-dir <path>   Directory for the generated summary. Default: a temp directory.
      --json-output <path>  JSON summary path. Default: <output-dir>/malicious-open-summary.json.
      --user <name>         Limit to one manifest key, user name, or numeric user id. May be repeated.
  -h, --help                Show this help.

This script is read-only. It does not connect to FISCO BCOS and does not require secrets.
EOF
}

manifest_path=""
output_dir=""
json_output=""
user_filters=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    -m|--manifest)
      manifest_path="${2:?--manifest requires a value}"
      shift 2
      ;;
    -o|--output-dir)
      output_dir="${2:?--output-dir requires a value}"
      shift 2
      ;;
    --json-output)
      json_output="${2:?--json-output requires a value}"
      shift 2
      ;;
    --user)
      user_filters+=("${2:?--user requires a value}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      if [ -z "$manifest_path" ]; then
        manifest_path="$1"
      elif [ -z "$output_dir" ]; then
        output_dir="$1"
      else
        echo "Unexpected argument: $1" >&2
        usage
        exit 2
      fi
      shift
      ;;
  esac
done

if [ -z "$manifest_path" ]; then
  echo "Missing manifest path." >&2
  usage
  exit 2
fi

if [ ! -f "$manifest_path" ]; then
  echo "Manifest not found: $manifest_path" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

host_path() {
  local path="$1"
  if [ -z "$path" ]; then
    return 0
  fi
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -a "$path"
  elif command -v realpath >/dev/null 2>&1; then
    realpath -m "$path"
  elif [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$PWD" "$path"
  fi
}

python_bin="${PYTHON_BIN:-python3}"
if ! command -v "$python_bin" >/dev/null 2>&1 || ! "$python_bin" -c 'import json' >/dev/null 2>&1; then
  python_bin="python"
fi
if ! command -v "$python_bin" >/dev/null 2>&1 || ! "$python_bin" -c 'import json' >/dev/null 2>&1; then
  echo "Required command not found: python3 or python" >&2
  exit 2
fi

user_filter_text=""
if [ "${#user_filters[@]}" -gt 0 ]; then
  user_filter_text="$(printf '%s\n' "${user_filters[@]}")"
fi

GSTBK_MALICIOUS_OPEN_REPO_ROOT="$(host_path "$repo_root")" \
GSTBK_MALICIOUS_OPEN_MANIFEST="$(host_path "$manifest_path")" \
GSTBK_MALICIOUS_OPEN_OUTPUT_DIR="$(host_path "$output_dir")" \
GSTBK_MALICIOUS_OPEN_JSON_OUTPUT="$(host_path "$json_output")" \
GSTBK_MALICIOUS_OPEN_USERS="$user_filter_text" \
  "$python_bin" <<'PY'
import datetime as dt
import hashlib
import json
import os
import re
import tempfile
from pathlib import Path


repo_root = Path(os.environ["GSTBK_MALICIOUS_OPEN_REPO_ROOT"]).resolve()
manifest_path = Path(os.environ["GSTBK_MALICIOUS_OPEN_MANIFEST"]).resolve()
output_env = os.environ.get("GSTBK_MALICIOUS_OPEN_OUTPUT_DIR", "")
json_output_env = os.environ.get("GSTBK_MALICIOUS_OPEN_JSON_OUTPUT", "")
user_filters = {
    value.strip()
    for value in os.environ.get("GSTBK_MALICIOUS_OPEN_USERS", "").splitlines()
    if value.strip()
}


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON manifest: {path}: {exc}") from exc


def utc_now():
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0)


def nested(obj, *keys, default=None):
    value = obj
    for key in keys:
        if not isinstance(value, dict) or key not in value:
            return default
        value = value[key]
    return value


def sha256_if_exists(path: Path):
    try:
        if path.is_file():
            return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None
    return None


def read_text_if_exists(path: Path):
    try:
        if path.is_file():
            return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    return None


def manifest_log_dir(manifest):
    for candidate in (
        nested(manifest, "runtime", "log_dir"),
        manifest.get("log_dir"),
        manifest.get("runtime_log_dir"),
    ):
        if candidate:
            return Path(candidate)
    return manifest_path.parent


def materialized_path(path_text):
    if not path_text:
        return None
    path = Path(path_text)
    if path.exists():
        return path
    fallback = log_dir / path.name
    if fallback.exists():
        return fallback
    chain_fallback = log_dir / "chain" / path.name
    if chain_fallback.exists():
        return chain_fallback
    return path


def table_cell(value):
    if value is None or value == "":
        text = "-"
    elif isinstance(value, bool):
        text = "true" if value else "false"
    else:
        text = str(value)
    return text.replace("\r", " ").replace("\n", "<br>").replace("|", "\\|")


def code(value):
    if value is None or value == "":
        return "-"
    return "`" + str(value).replace("`", "\\`").replace("\r", " ").replace("\n", " ") + "`"


def md_table(headers, rows):
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    if rows:
        for row in rows:
            lines.append("| " + " | ".join(table_cell(value) for value in row) + " |")
    else:
        lines.append("| " + " | ".join("-" for _ in headers) + " |")
    return "\n".join(lines)


def natural_user_sort(item):
    key, _value = item
    suffix = key.removeprefix("user")
    if suffix.isdigit():
        return (0, int(suffix))
    return (1, key)


def user_id_from_key(key):
    match = re.search(r"(\d+)$", key)
    return match.group(1) if match else None


def role_logs_from_manifest(manifest):
    logs = nested(manifest, "roles", "logs", default={})
    result = {}
    if isinstance(logs, dict):
        for name, info in logs.items():
            if isinstance(info, dict):
                result[name] = dict(info)
            else:
                result[name] = {"path": str(info)}
    return result


def role_log_sources(info):
    sources = []
    seen = set()

    def add(kind, path_text, sha256=None):
        if not path_text:
            return
        key = str(path_text)
        if key in seen:
            return
        seen.add(key)
        source = {"kind": kind, "path": key}
        if sha256:
            source["sha256"] = sha256
        sources.append(source)

    add("stdout", info.get("path"), info.get("sha256"))
    add("log4rs_file", info.get("file_log_path"), info.get("file_log_sha256"))
    for source in info.get("sources", []):
        if isinstance(source, dict):
            add(source.get("kind") or "log", source.get("path"), source.get("sha256"))
    return sources


def read_role_log_text(sources):
    texts = []
    readable_sources = []
    for source in sources:
        path_text = source.get("path")
        resolved = materialized_path(path_text)
        text = read_text_if_exists(resolved) if resolved else None
        sha256 = source.get("sha256") or (sha256_if_exists(resolved) if resolved else None)
        if sha256:
            source["sha256"] = sha256
        if text is not None:
            texts.append(text)
            readable_sources.append(dict(source))
    if not texts:
        return None, readable_sources
    return "\n".join(texts), readable_sources


def format_log_source_paths(sources):
    values = [
        f"{source.get('kind', 'log')}: {code(source.get('path'))}"
        for source in sources
        if source.get("path")
    ]
    return "<br>".join(values) if values else "-"


def format_log_source_sha256(sources):
    values = [
        f"{source.get('kind', 'log')}: {code(source.get('sha256'))}"
        for source in sources
        if source.get("sha256")
    ]
    return "<br>".join(values) if values else "-"


def log_message(line):
    stripped = line.strip()
    if " - " in stripped:
        return stripped.split(" - ", 1)[1].strip()
    return stripped


def update_reveal_fields(fields, message):
    if message.startswith("user_id:"):
        fields["user_id"] = message.split(":", 1)[1].strip()
    elif message.startswith("user_name:"):
        fields["user_name"] = message.split(":", 1)[1].strip()
    elif message.startswith("user address:"):
        fields["address"] = message.split(":", 1)[1].strip().strip('"')


def log_status_for_user(text, user_id):
    empty_reveal_fields = {
        "user_id": None,
        "user_name": None,
        "address": None,
        "lines": [],
    }
    if text is None:
        return {
            "signature_query": "日志未读取",
            "signature_query_status": "log_unread",
            "verify": "日志未读取",
            "verify_status": "log_unread",
            "open": "日志未读取",
            "open_status": "log_unread",
            "raw_open_status": "log_unread",
            "open_triggered_by_user": False,
            "reveal": "-",
            "reveal_fields": empty_reveal_fields,
        }

    signature_query_found = "Signature query stdout:" in text and "exists true" in text
    signature_query = "exists true" if signature_query_found else "未出现"
    signature_query_status = "exists_true" if signature_query_found else "not_seen"
    verify = "未出现"
    verify_status = "not_seen"
    if user_id:
        invalid_patterns = [
            f"User {user_id} Proxy::verify_phase() : invalid signature",
            f"User {user_id} Proxy::verify_phase() : invalid hash",
            f"User {user_id} Node::verify_phase() : invalid signature",
        ]
        if any(pattern in text for pattern in invalid_patterns):
            verify = "失败，触发 Open"
            verify_status = "failed_triggers_open"
        elif f"User {user_id} Node::verify_phase() : verify successfully" in text:
            verify = "通过"
            verify_status = "passed"
    elif "verify successfully" in text:
        verify = "通过"
        verify_status = "passed"
    elif "invalid signature" in text or "invalid hash" in text:
        verify = "失败，触发 Open"
        verify_status = "failed_triggers_open"

    if "Open phase is finished" in text:
        raw_open_status = "completed"
        raw_open_text = "完成"
    elif "Open Phase is starting" in text:
        raw_open_status = "started_not_finished"
        raw_open_text = "开始未完成"
    else:
        raw_open_status = "not_seen"
        raw_open_text = "未出现"

    open_triggered_by_user = verify_status == "failed_triggers_open" and raw_open_status in {
        "completed",
        "started_not_finished",
    }
    if verify_status == "passed" and raw_open_status == "completed":
        open_status = "全局完成，非本用户触发"
        normalized_open_status = "global_completed_not_triggered_by_user"
    elif verify_status == "passed" and raw_open_status == "started_not_finished":
        open_status = "全局开始，非本用户触发"
        normalized_open_status = "global_started_not_triggered_by_user"
    else:
        open_status = raw_open_text
        normalized_open_status = raw_open_status
    reveal_lines = []
    reveal_fields = dict(empty_reveal_fields)
    if user_id:
        capture_reveal = False
        for line in text.splitlines():
            stripped = log_message(line)
            if (
                f"This user {user_id}" in stripped
                or f"user_id:{user_id}" in stripped
            ):
                capture_reveal = True
                reveal_lines.append(stripped)
                update_reveal_fields(reveal_fields, stripped)
            elif stripped.startswith("This user ") or stripped.startswith("user_id:"):
                capture_reveal = False
            elif capture_reveal and (
                stripped.startswith("user_name:")
                or stripped.startswith("user address:")
            ):
                reveal_lines.append(stripped)
                update_reveal_fields(reveal_fields, stripped)
    else:
        for line in text.splitlines():
            stripped = log_message(line)
            if "maybe malicious" in stripped or "user_id:" in stripped or "user_name:" in stripped or "user address:" in stripped:
                reveal_lines.append(stripped)
                update_reveal_fields(reveal_fields, stripped)
    reveal_fields["lines"] = reveal_lines[-6:]
    if reveal_lines:
        reveal = "<br>".join(reveal_lines[-6:])
    elif verify_status == "failed_triggers_open" and normalized_open_status == "completed":
        reveal = "未捕获信息级揭示行；本次真实日志保留 Verify 失败和 Open 完成"
    else:
        reveal = "-"
    return {
        "signature_query": signature_query,
        "signature_query_status": signature_query_status,
        "verify": verify,
        "verify_status": verify_status,
        "open": open_status,
        "open_status": normalized_open_status,
        "raw_open_status": raw_open_status,
        "open_triggered_by_user": open_triggered_by_user,
        "reveal": reveal,
        "reveal_fields": reveal_fields,
    }


manifest = load_json(manifest_path)
log_dir = manifest_log_dir(manifest)
if not log_dir.is_absolute():
    log_dir = (manifest_path.parent / log_dir).resolve()
if not log_dir.is_dir() and manifest_path.parent.is_dir():
    log_dir = manifest_path.parent

generated_at_dt = utc_now()
generated_at = generated_at_dt.isoformat().replace("+00:00", "Z")
timestamp = generated_at_dt.strftime("%Y%m%dT%H%M%SZ")
if output_env:
    output_dir = Path(output_env)
else:
    output_dir = Path(tempfile.gettempdir()) / f"gstbk-malicious-open-{timestamp}"
if not output_dir.is_absolute():
    output_dir = (repo_root / output_dir).resolve()
output_dir.mkdir(parents=True, exist_ok=True)
if json_output_env:
    json_output_path = Path(json_output_env)
else:
    json_output_path = output_dir / "malicious-open-summary.json"
if not json_output_path.is_absolute():
    json_output_path = (repo_root / json_output_path).resolve()
json_output_path.parent.mkdir(parents=True, exist_ok=True)

chain_results = manifest.get("chain_results")
if not isinstance(chain_results, dict) or not chain_results:
    raise SystemExit("Manifest does not contain chain_results")

identity = manifest.get("identity") if isinstance(manifest.get("identity"), dict) else {}
users = []
for manifest_key, user_data in sorted(chain_results.items(), key=natural_user_sort):
    if not isinstance(user_data, dict):
        continue
    user_name = user_data.get("user_name") or manifest_key
    user_id = user_id_from_key(manifest_key)
    if user_filters and manifest_key not in user_filters and user_name not in user_filters and user_id not in user_filters:
        continue
    users.append((manifest_key, user_id, user_name, user_data))

if not users:
    raise SystemExit("No users matched the manifest and --user filters")

users_summary = []
tx_hashes = {}
block_numbers = {}
for manifest_key, user_id, user_name, user_data in users:
    entry = "sign_wrong" if manifest_key == "user1" else "sign"
    role = "恶意演示目标" if manifest_key == "user1" else "正常对照用户"
    users_summary.append(
        {
            "manifest_key": manifest_key,
            "user_id": user_id,
            "user_name": user_name,
            "entry_point": entry,
            "role": role,
        }
    )
    tx_hashes[manifest_key] = {}
    block_numbers[manifest_key] = {}
    registers = user_data.get("registers") if isinstance(user_data.get("registers"), dict) else {}
    for contract_key in ("signature", "personal_info"):
        register = registers.get(contract_key) if isinstance(registers.get(contract_key), dict) else {}
        if register.get("transaction_hash"):
            tx_hashes[manifest_key][contract_key] = register.get("transaction_hash")
        if register.get("block_number"):
            block_numbers[manifest_key][contract_key] = register.get("block_number")

role_logs = role_logs_from_manifest(manifest)
node_logs = {
    name: info
    for name, info in role_logs.items()
    if re.fullmatch(r"node\d+", name)
}

chain_records = []
chain_rows = []
for manifest_key, user_id, user_name, user_data in users:
    registers = user_data.get("registers") if isinstance(user_data.get("registers"), dict) else {}
    selects = user_data.get("selects") if isinstance(user_data.get("selects"), dict) else {}
    identity_item = identity.get(manifest_key) if isinstance(identity.get(manifest_key), dict) else {}
    for contract_key, contract_label, select_key in [
        ("signature", "Signature", "signature_select"),
        ("personal_info", "PersonalInfo", "personal_info_select"),
    ]:
        register = registers.get(contract_key) if isinstance(registers.get(contract_key), dict) else {}
        select = selects.get(select_key) if isinstance(selects.get(select_key), dict) else {}
        if not register and not select:
            continue
        chain_record = {
            "manifest_user": manifest_key,
            "user_id": user_id,
            "user_name": user_name,
            "contract_key": contract_key,
            "contract": contract_label,
            "tx_hash": register.get("transaction_hash"),
            "block_number": register.get("block_number"),
            "ret": register.get("ret"),
            "select_exists": select.get("exists"),
            "select_log_path": select.get("path"),
            "select_log_sha256": select.get("sha256"),
            "identity_ciphertext_sha256": (
                identity_item.get("sha256") if contract_key == "personal_info" else None
            ),
        }
        chain_records.append(chain_record)
        chain_rows.append([
            manifest_key,
            user_name,
            contract_label,
            code(register.get("transaction_hash")),
            register.get("block_number"),
            register.get("ret"),
            select.get("exists"),
            code(select.get("path")),
            code(select.get("sha256")),
            code(identity_item.get("sha256")) if contract_key == "personal_info" else "-",
        ])

role_statuses = []
role_rows = []
role_log_sha256 = {}
for manifest_key, user_id, user_name, _user_data in users:
    for node_name, info in sorted(node_logs.items()):
        log_path = info.get("path")
        sources = role_log_sources(info)
        text, readable_sources = read_role_log_text(sources)
        status = log_status_for_user(text, user_id)
        log_hash = None
        for source in sources:
            source_path = source.get("path")
            source_hash = source.get("sha256")
            if source_path and source_hash:
                role_log_sha256[str(source_path)] = source_hash
            if source_path == log_path:
                log_hash = source_hash
        role_statuses.append(
            {
                "manifest_user": manifest_key,
                "user_id": user_id,
                "user_name": user_name,
                "node": node_name,
                "log_path": log_path,
                "log_sha256": log_hash,
                "log_sources": readable_sources,
                "signature_query": status["signature_query"],
                "signature_query_status": status["signature_query_status"],
                "verify": status["verify"],
                "verify_status": status["verify_status"],
                "open": status["open"],
                "open_status": status["open_status"],
                "raw_open_status": status["raw_open_status"],
                "open_triggered_by_user": status["open_triggered_by_user"],
                "reveal": status["reveal"],
                "reveal_fields": status["reveal_fields"],
            }
        )
        role_rows.append([
            user_name,
            node_name,
            format_log_source_paths(sources),
            format_log_source_sha256(sources),
            status["signature_query"],
            status["verify"],
            status["open"],
            status["reveal"],
        ])

target_summary = []
target_rows = []
for manifest_key, user_id, user_name, _user_data in users:
    entry = "sign_wrong" if manifest_key == "user1" else "sign"
    role = "恶意演示目标" if manifest_key == "user1" else "正常对照用户"
    target_summary.append(
        {
            "manifest_key": manifest_key,
            "user_id": user_id,
            "user_name": user_name,
            "entry_point": entry,
            "role": role,
        }
    )
    target_rows.append([manifest_key, user_id, user_name, entry, role])

summary = [
    "# 恶意用户 Verify（验证）/Open（揭示）摘要",
    "",
    "本报告由 `scripts/evidence/run-malicious-open-demo.sh` 从 E2E（End-to-End，端到端）Manifest（运行清单）和角色 stdout（标准输出）/log4rs（Rust 日志框架）日志生成。脚本只读本地文件，不连接 FISCO BCOS（金融区块链合作联盟开源区块链底层平台），也不需要真实证书、账户或配置。",
    "",
    "## 运行来源",
    "",
    md_table(
        ["字段", "值"],
        [
            ["Manifest", code(manifest_path)],
            ["日志目录", code(log_dir)],
            ["输出目录", code(output_dir)],
            ["E2E 成功", manifest.get("success")],
            ["命令", code(manifest.get("command"))],
        ],
    ),
    "",
    "## demo（演示）用户",
    "",
    md_table(["Manifest 用户", "协议用户编号", "链上用户名", "签名入口", "判读角色"], target_rows),
    "",
    "## 链上证据",
    "",
    md_table(
        ["Manifest 用户", "链上用户名", "合约", "TX（Transaction，交易）哈希", "区块", "ret", "select exists", "select 日志", "select SHA-256", "身份密文 SHA-256"],
        chain_rows,
    ),
    "",
    "## Verify/Open 日志摘录",
    "",
    md_table(
        ["链上用户名", "Node（管理员节点）", "日志路径", "日志 SHA-256", "Signature 查询", "Verify 结果", "Open 状态", "揭示摘录"],
        role_rows,
    ),
    "",
    "## 判读口径",
    "",
    "- `Signature 查询` 为 `exists true` 表示 Node 已从链上取到签名 JSON（JavaScript Object Notation，数据交换格式）。",
    "- `Verify 结果` 为 `失败，触发 Open` 表示本地签名校验失败，随后进入 Open（揭示）。",
    "- `揭示摘录` 出现 `maybe malicious`、`user_id`、`user_name` 和 `user address` 时，可以把匿名签名定位回具体用户。",
    "- `揭示摘录` 显示未捕获信息级揭示行时，表示当前 manifest（运行清单）可读取的角色日志来源中仍没有 `info!` 信息级揭示行；应先确认 E2E（End-to-End，端到端）运行是否已收集 Node 的 log4rs（Rust 日志框架）文件日志。",
]

summary_path = output_dir / "malicious-open-summary.md"
summary_path.write_text("\n".join(summary) + "\n", encoding="utf-8")
summary_sha256 = sha256_if_exists(summary_path)
contracts = nested(manifest, "chain", "contracts", default={}) or {}
global_open_observed = any(
    item["raw_open_status"] in {"completed", "started_not_finished"}
    for item in role_statuses
)
notes = [
    "Markdown（轻量标记语言）摘要继续写入 malicious-open-summary.md，JSON（JavaScript Object Notation，数据交换格式）用于 Web（网页）/API（Application Programming Interface，应用程序接口）展示和 AI（Artificial Intelligence，人工智能）安全审计材料复用。",
    "user1 是 sign_wrong 恶意演示目标；user2 是 sign 正常对照用户。",
    "当用户 Verify（验证）通过但同一轮日志存在 Open（揭示）阶段时，open_status 记录为 global_completed_not_triggered_by_user 或 global_started_not_triggered_by_user，表示全局完成/开始且非本用户触发。",
    "若 E2E manifest（运行清单）包含 role log_sources 或 file_log_path，摘要会合并 stdout（标准输出）和 log4rs（Rust 日志框架）文件日志后提取 user_id、user_name 与 address 揭示字段。",
]
json_summary = {
    "generated_at": generated_at,
    "manifest": {
        "path": str(manifest_path),
        "sha256": sha256_if_exists(manifest_path),
        "success": manifest.get("success"),
        "command": manifest.get("command"),
        "runtime_log_dir": str(log_dir),
    },
    "output_dir": str(output_dir),
    "markdown_summary": str(summary_path),
    "json_summary": str(json_output_path),
    "success": True,
    "users": users_summary,
    "contract_addresses": contracts,
    "tx_hashes": tx_hashes,
    "block_numbers": block_numbers,
    "query_results": chain_records,
    "verify_open_status": {
        "global_open_observed": global_open_observed,
        "targets": target_summary,
        "role_logs": role_statuses,
    },
    "log_sha256": {
        "markdown_summary": summary_sha256,
        "role_logs": role_log_sha256,
    },
    "notes": notes,
}
json_output_path.write_text(
    json.dumps(json_summary, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)

print(f"summary {summary_path}")
print(f"jsonSummary {json_output_path}")
print(f"outputDir {output_dir}")
for row in target_rows:
    print(f"user {row[0]} id {row[1]} name {row[2]} entry {row[3]} role {row[4]}")
PY
