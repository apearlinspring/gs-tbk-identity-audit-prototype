#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/evidence/run-audit-query-demo.sh --manifest <manifest.json> [options]

Options:
  -m, --manifest <path>     run-e2e manifest JSON containing users, TX hashes and block numbers.
  -o, --output-dir <path>   Directory for query outputs. Default: a temp directory.
      --json-output <path>  JSON summary path. Default: <output-dir>/audit-query-summary.json.
      --user <name>         Limit to one manifest key or user id. May be repeated.
      --dry-run             Print commands and write the summary without calling the chain.
  -h, --help                Show this help.

Required for live queries:
  FISCO_CONFIG points to a local, ignored Java SDK config.
  GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS and GSTBK_SIGNATURE_CONTRACT_ADDRESS are either set
  in the environment or present in the manifest.
EOF
}

manifest_path=""
output_dir=""
json_output=""
dry_run="false"
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
    --dry-run)
      dry_run="true"
      shift
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

GSTBK_AUDIT_QUERY_REPO_ROOT="$(host_path "$repo_root")" \
GSTBK_AUDIT_QUERY_MANIFEST="$(host_path "$manifest_path")" \
GSTBK_AUDIT_QUERY_OUTPUT_DIR="$(host_path "$output_dir")" \
GSTBK_AUDIT_QUERY_JSON_OUTPUT="$(host_path "$json_output")" \
GSTBK_AUDIT_QUERY_DRY_RUN="$dry_run" \
GSTBK_AUDIT_QUERY_USERS="$user_filter_text" \
  "$python_bin" <<'PY'
import datetime as dt
import hashlib
import json
import os
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path


repo_root = Path(os.environ["GSTBK_AUDIT_QUERY_REPO_ROOT"]).resolve()
manifest_path = Path(os.environ["GSTBK_AUDIT_QUERY_MANIFEST"]).resolve()
output_env = os.environ.get("GSTBK_AUDIT_QUERY_OUTPUT_DIR", "")
json_output_env = os.environ.get("GSTBK_AUDIT_QUERY_JSON_OUTPUT", "")
dry_run = os.environ.get("GSTBK_AUDIT_QUERY_DRY_RUN") == "true"
user_filters = {
    value.strip()
    for value in os.environ.get("GSTBK_AUDIT_QUERY_USERS", "").splitlines()
    if value.strip()
}


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON manifest: {path}: {exc}") from exc


def utc_now():
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0)


def sha256_if_exists(path: Path):
    try:
        if path.is_file():
            return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None
    return None


def nested(obj, *keys, default=None):
    value = obj
    for key in keys:
        if not isinstance(value, dict) or key not in value:
            return default
        value = value[key]
    return value


def natural_user_sort(item):
    key, _value = item
    suffix = key.removeprefix("user")
    if suffix.isdigit():
        return (0, int(suffix))
    return (1, key)


def shell_command(args):
    return shlex.join(str(arg) for arg in args)


def relative_command(args):
    rendered = []
    for arg in args:
        text = str(arg)
        try:
            path = Path(text)
            if path.is_absolute():
                text = str(path.relative_to(repo_root))
        except (ValueError, OSError):
            pass
        rendered.append(text)
    return shell_command(rendered)


def parse_field(output, field):
    prefix = field + " "
    for line in output.splitlines():
        if line.startswith(prefix):
            return line[len(prefix):].strip()
    return None


def value_is_present(value):
    return value not in (None, "", "0", "null", "None")


def run_step(command, output_path):
    if dry_run:
        return {"status": "dry-run", "returncode": None, "stdout": ""}

    result = subprocess.run(
        [str(arg) for arg in command],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    output_path.write_text(result.stdout, encoding="utf-8")
    if result.returncode != 0:
        print(result.stdout, end="")
        raise SystemExit(
            f"Command failed with exit {result.returncode}: {shell_command(command)}"
        )
    return {"status": "ok", "returncode": result.returncode, "stdout": result.stdout}


manifest = load_json(manifest_path)
generated_at_dt = utc_now()
generated_at = generated_at_dt.isoformat().replace("+00:00", "Z")
timestamp = generated_at_dt.strftime("%Y%m%dT%H%M%SZ")
if output_env:
    output_dir = Path(output_env)
else:
    output_dir = Path(tempfile.gettempdir()) / f"gstbk-audit-query-{timestamp}"
if not output_dir.is_absolute():
    output_dir = (repo_root / output_dir).resolve()
output_dir.mkdir(parents=True, exist_ok=True)
if json_output_env:
    json_output_path = Path(json_output_env)
else:
    json_output_path = output_dir / "audit-query-summary.json"
if not json_output_path.is_absolute():
    json_output_path = (repo_root / json_output_path).resolve()
json_output_path.parent.mkdir(parents=True, exist_ok=True)

default_app_dir = repo_root / "chain-apps" / "fisco-bcos-java-sdk"
personal_info_app_dir = Path(os.environ.get("GSTBK_PERSONAL_INFO_APP_DIR", default_app_dir))
signature_app_dir = Path(os.environ.get("GSTBK_SIGNATURE_APP_DIR", default_app_dir))
if not personal_info_app_dir.is_absolute():
    personal_info_app_dir = (repo_root / personal_info_app_dir).resolve()
if not signature_app_dir.is_absolute():
    signature_app_dir = (repo_root / signature_app_dir).resolve()

scripts = {
    "signature": signature_app_dir / "signature_run.sh",
    "personal_info": personal_info_app_dir / "info_run.sh",
}
contracts = nested(manifest, "chain", "contracts", default={}) or {}
addresses = {
    "signature": os.environ.get("GSTBK_SIGNATURE_CONTRACT_ADDRESS") or contracts.get("signature"),
    "personal_info": (
        os.environ.get("GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS")
        or contracts.get("personal_info")
    ),
}
contract_labels = {
    "signature": "Signature",
    "personal_info": "PersonalInfo",
}
value_labels = {
    "signature": "signature",
    "personal_info": "info",
}

missing = []
for key, script in scripts.items():
    if not script.is_file():
        missing.append(f"{contract_labels[key]} runner not found: {script}")
    if not addresses.get(key):
        missing.append(f"{contract_labels[key]} contract address is missing")
if not dry_run and not os.environ.get("FISCO_CONFIG"):
    missing.append("FISCO_CONFIG is required for live queries")
if missing:
    for item in missing:
        print(item, file=sys.stderr)
    raise SystemExit(2)

chain_results = manifest.get("chain_results")
if not isinstance(chain_results, dict) or not chain_results:
    raise SystemExit("Manifest does not contain chain_results")

selected_users = []
for manifest_key, user_data in sorted(chain_results.items(), key=natural_user_sort):
    if not isinstance(user_data, dict):
        continue
    user_name = user_data.get("user_name") or manifest_key
    if user_filters and manifest_key not in user_filters and user_name not in user_filters:
        continue
    selected_users.append((manifest_key, user_name, user_data))

if not selected_users:
    raise SystemExit("No users matched the manifest and --user filters")

rows = []
users_summary = []
tx_hashes = {}
block_numbers = {}
query_log_sha256 = {}
for manifest_key, user_name, user_data in selected_users:
    users_summary.append(
        {
            "manifest_key": manifest_key,
            "user_name": user_name,
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

summary = [
    "# 链上审计查询复核",
    "",
    "本报告由 `scripts/evidence/run-audit-query-demo.sh` 生成，只记录只读查询命令、TX（Transaction，交易）哈希、区块高度和输出文件路径。",
    "",
    f"- Manifest（运行清单）：`{manifest_path}`",
    f"- 输出目录：`{output_dir}`",
    f"- dry-run（只打印命令）：`{str(dry_run).lower()}`",
    "",
    "## 查询步骤",
    "",
    "| 用户 | 合约 | TX 哈希 | 登记区块 | 查询 | 命令 | 输出 | 结果 |",
    "| --- | --- | --- | --- | --- | --- | --- | --- |",
]

for manifest_key, user_name, user_data in selected_users:
    registers = user_data.get("registers") if isinstance(user_data.get("registers"), dict) else {}
    for contract_key in ("signature", "personal_info"):
        register = registers.get(contract_key) if isinstance(registers.get(contract_key), dict) else {}
        block_number = register.get("block_number")
        tx_hash = register.get("transaction_hash")
        if not block_number:
            continue

        contract_label = contract_labels[contract_key]
        value_label = value_labels[contract_key]
        script = scripts[contract_key]
        address = addresses[contract_key]
        base_name = f"{manifest_key}-{contract_key.replace('_', '-')}"

        steps = [
            ("select", ["bash", script, "select", address, user_name], f"{base_name}-select.out"),
            (
                "history@block",
                ["bash", script, "history", address, user_name, str(block_number)],
                f"{base_name}-history-block-{block_number}.out",
            ),
        ]
        try:
            previous_block = int(str(block_number)) - 1
        except ValueError:
            previous_block = None
        if previous_block and previous_block > 0:
            steps.append(
                (
                    "history@previous-block",
                    ["bash", script, "history", address, user_name, str(previous_block)],
                    f"{base_name}-history-block-{previous_block}.out",
                )
            )

        for query_label, command, file_name in steps:
            output_path = output_dir / file_name
            result = run_step(command, output_path)
            stdout = result["stdout"]
            parsed = "-"
            exists = None
            ret = None
            value_present = None
            if stdout:
                exists = parse_field(stdout, "exists")
                ret = parse_field(stdout, "ret")
                value = parse_field(stdout, value_label)
                if exists is not None:
                    parsed = f"exists {exists}"
                elif ret is not None:
                    parsed = f"ret {ret}"
                if value_is_present(value):
                    parsed = f"{parsed}; {value_label} present"
                    value_present = True
                elif value is not None:
                    parsed = f"{parsed}; {value_label} absent"
                    value_present = False
            elif dry_run:
                parsed = "dry-run"
            output_sha256 = sha256_if_exists(output_path)
            if output_sha256:
                query_log_sha256[str(output_path)] = output_sha256

            rows.append(
                {
                    "manifest_user": manifest_key,
                    "user": user_name,
                    "contract_key": contract_key,
                    "contract": contract_label,
                    "tx_hash": tx_hash or "-",
                    "block_number": block_number,
                    "query": query_label,
                    "command": relative_command(command),
                    "output": str(output_path),
                    "output_sha256": output_sha256,
                    "status": result["status"],
                    "returncode": result["returncode"],
                    "exists": exists,
                    "ret": ret,
                    "value_present": value_present,
                    "result": parsed,
                }
            )

for row in rows:
    summary.append(
        "| {user} | `{contract}` | `{tx_hash}` | `{block_number}` | `{query}` | `{command}` | `{output}` | {result} |".format(
            user=str(row["user"]).replace("|", "\\|"),
            contract=str(row["contract"]).replace("|", "\\|"),
            tx_hash=str(row["tx_hash"]).replace("|", "\\|"),
            block_number=str(row["block_number"]).replace("|", "\\|"),
            query=str(row["query"]).replace("|", "\\|"),
            command=str(row["command"]).replace("`", "\\`").replace("|", "\\|"),
            output=str(row["output"]).replace("`", "\\`").replace("|", "\\|"),
            result=str(row["result"]).replace("|", "\\|"),
        )
    )

summary.extend(
    [
        "",
        "## 判读口径",
        "",
        "- `select` 返回 `exists true` 时，说明当前主键仍可查到该用户的最新链上记录。",
        "- `history@block` 返回 `ret 0` 时，说明可按登记区块追溯到该区块写入的历史记录。",
        "- `history@previous-block` 通常返回 `ret -2`，用于证明登记前一区块尚无该用户的历史快照。",
    ]
)

summary_path = output_dir / "audit-query-summary.md"
summary_path.write_text("\n".join(summary) + "\n", encoding="utf-8")
summary_sha256 = sha256_if_exists(summary_path)

notes = [
    "Markdown（轻量标记语言）摘要继续写入 audit-query-summary.md，JSON（JavaScript Object Notation，数据交换格式）仅提供机器可读索引和判读结果。",
    "查询输出文件只记录路径和 SHA-256（安全哈希算法 256 位），不把可能较大的链上签名或身份密文 JSON 嵌入摘要。",
]
if dry_run:
    notes.append("dry-run（只打印命令）模式未连接真实链，query_results 中的输出文件 SHA-256 为空属预期。")

json_summary = {
    "generated_at": generated_at,
    "manifest": {
        "path": str(manifest_path),
        "sha256": sha256_if_exists(manifest_path),
        "success": manifest.get("success"),
        "command": manifest.get("command"),
        "runtime_log_dir": nested(manifest, "runtime", "log_dir")
        or manifest.get("log_dir")
        or manifest.get("runtime_log_dir"),
    },
    "output_dir": str(output_dir),
    "markdown_summary": str(summary_path),
    "json_summary": str(json_output_path),
    "success": True,
    "users": users_summary,
    "contract_addresses": addresses,
    "tx_hashes": tx_hashes,
    "block_numbers": block_numbers,
    "query_results": rows,
    "verify_open_status": {
        "status": "not_applicable",
        "reason": "run-audit-query-demo.sh 只执行链上只读查询，不判定 Verify/Open（验证/揭示）流程。",
    },
    "log_sha256": {
        "markdown_summary": summary_sha256,
        "query_outputs": query_log_sha256,
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
for row in rows:
    print(
        "{user} {contract} {query} block {block_number} tx {tx_hash} -> {output}".format(
            **row
        )
    )
PY
