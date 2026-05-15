#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/evidence/generate-e2e-report.sh --manifest <manifest.json> [--output <report.md>]
  bash scripts/evidence/generate-e2e-report.sh <manifest.json> [report.md]

Options:
  -m, --manifest <path>   run-e2e/service manifest JSON to summarize.
  -o, --output <path>     Markdown report path. Default: docs/evidence/e2e-report-<timestamp>.md.
  -h, --help              Show this help.
EOF
}

manifest_path=""
output_path=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -m|--manifest)
      manifest_path="${2:?--manifest requires a value}"
      shift 2
      ;;
    -o|--output)
      output_path="${2:?--output requires a value}"
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
      elif [ -z "$output_path" ]; then
        output_path="$1"
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

manifest_path_host="$(host_path "$manifest_path")"
output_path_host="$(host_path "$output_path")"
repo_root_host="$(host_path "$repo_root")"

python_bin="${PYTHON_BIN:-python3}"
if ! command -v "$python_bin" >/dev/null 2>&1 || ! "$python_bin" -c 'import json' >/dev/null 2>&1; then
  python_bin="python"
fi
if ! command -v "$python_bin" >/dev/null 2>&1 || ! "$python_bin" -c 'import json' >/dev/null 2>&1; then
  echo "Required command not found: python3 or python" >&2
  exit 2
fi

GSTBK_E2E_REPORT_MANIFEST="$manifest_path_host" \
GSTBK_E2E_REPORT_OUTPUT="$output_path_host" \
GSTBK_E2E_REPORT_REPO_ROOT="$repo_root_host" \
  "$python_bin" <<'PY'
import datetime as dt
import hashlib
import json
import os
import re
import sys
from pathlib import Path


manifest_path = Path(os.environ["GSTBK_E2E_REPORT_MANIFEST"]).resolve()
output_env = os.environ.get("GSTBK_E2E_REPORT_OUTPUT", "")
repo_root = Path(os.environ["GSTBK_E2E_REPORT_REPO_ROOT"]).resolve()


def load_manifest(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON manifest: {path}: {exc}") from exc


manifest = load_manifest(manifest_path)


def nested(obj, *keys, default=None):
    value = obj
    for key in keys:
        if not isinstance(value, dict) or key not in value:
            return default
        value = value[key]
    return value


def as_text(value, default="-"):
    if value is None or value == "":
        return default
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def table_cell(value):
    text = as_text(value)
    text = text.replace("\r", " ").replace("\n", "<br>")
    text = text.replace("|", "\\|")
    return text


def code(value):
    text = as_text(value)
    if text == "-":
        return text
    return "`" + text.replace("`", "\\`").replace("\r", " ").replace("\n", " ") + "`"


def code_cell(value):
    return table_cell(code(value))


def sha256_if_exists(path: Path):
    try:
        if path.is_file():
            return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None
    return None


def text_if_exists(path: Path):
    try:
        if path.is_file():
            return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    return None


def compact_timestamp():
    parent = manifest_path.parent.name
    if re.fullmatch(r"\d{8}T\d{6}Z", parent):
        return parent
    for key in ("start_timestamp", "end_timestamp"):
        value = manifest.get(key)
        if isinstance(value, str):
            match = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z", value)
            if match:
                return "".join(match.groups()[0:3]) + "T" + "".join(match.groups()[3:6]) + "Z"
    return dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


timestamp = compact_timestamp()
if output_env:
    output_path = Path(output_env)
else:
    output_path = repo_root / "docs" / "evidence" / f"e2e-report-{timestamp}.md"
if not output_path.is_absolute():
    output_path = (repo_root / output_path).resolve()


def manifest_log_dir():
    candidates = [
        nested(manifest, "runtime", "log_dir"),
        manifest.get("log_dir"),
        manifest.get("runtime_log_dir"),
    ]
    for candidate in candidates:
        if candidate:
            return Path(candidate)
    return manifest_path.parent


log_dir = manifest_log_dir()
if not log_dir.is_absolute():
    log_dir = (manifest_path.parent / log_dir).resolve()
if not log_dir.is_dir() and manifest_path.parent.is_dir():
    # Fixture reports may mirror VM paths in manifest fields while keeping small logs
    # next to the fixture manifest inside this repository.
    log_dir = manifest_path.parent


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


def parse_registers(text):
    result = {}
    current = None
    for line in text.splitlines():
        if line.startswith("Signature register stdout:"):
            current = "signature"
            result.setdefault(current, {})
        elif line.startswith("PersonalInfo register stdout:"):
            current = "personal_info"
            result.setdefault(current, {})
        elif current and line.startswith("transactionHash "):
            result[current]["transaction_hash"] = line.split(maxsplit=1)[1]
        elif current and line.startswith("blockNumber "):
            result[current]["block_number"] = line.split(maxsplit=1)[1]
        elif current and line.startswith("ret "):
            result[current]["ret"] = line.split(maxsplit=1)[1]
    return result


def role_logs_from_manifest():
    logs = nested(manifest, "roles", "logs", default={})
    result = {}
    if isinstance(logs, dict):
        for name, info in logs.items():
            if isinstance(info, dict):
                result[name] = dict(info)
            else:
                result[name] = {"path": str(info)}
    return result


def discover_log_artifacts():
    artifacts = {}
    role_logs = role_logs_from_manifest()
    for name, info in role_logs.items():
        path_text = info.get("path")
        if path_text:
            artifacts[f"{name} log"] = {
                "path": path_text,
                "sha256": info.get("sha256"),
            }
        command_path_text = info.get("command_path")
        if command_path_text:
            artifacts[f"{name} command"] = {
                "path": command_path_text,
                "sha256": info.get("command_sha256"),
            }

    known_names = {
        Path(item["path"]).name
        for item in artifacts.values()
        if item.get("path")
    }
    known_names.add("manifest.json")
    if log_dir.is_dir():
        for path in sorted(log_dir.iterdir()):
            if not path.is_file():
                continue
            if path.suffix not in {".out", ".log", ".command", ".json"}:
                continue
            if path.name in known_names:
                continue
            key = path.name
            artifacts.setdefault(key, {"path": str(path), "sha256": None})
        chain_dir = log_dir / "chain"
        if chain_dir.is_dir():
            for path in sorted(chain_dir.iterdir()):
                if not path.is_file():
                    continue
                if path.suffix not in {".out", ".log", ".command", ".json"}:
                    continue
                key = f"chain/{path.name}"
                artifacts.setdefault(key, {"path": str(path), "sha256": None})

    artifacts.setdefault("manifest", {"path": str(manifest_path), "sha256": None})
    for item in artifacts.values():
        path = materialized_path(item["path"])
        if item.get("sha256") in (None, ""):
            item["sha256"] = sha256_if_exists(path)
    return artifacts


artifacts = discover_log_artifacts()


def role_log_entries():
    entries = role_logs_from_manifest()
    if log_dir.is_dir():
        for path in sorted(log_dir.glob("*.out")) + sorted(log_dir.glob("*.log")):
            name = path.stem
            if re.fullmatch(r"proxy|node\d+|user\d+", name):
                entries.setdefault(name, {"path": str(path), "sha256": sha256_if_exists(path)})
    return entries


def stage_status(text, start_patterns, finish_patterns):
    if text is None:
        return "日志未读取"
    has_start = any(pattern in text for pattern in start_patterns)
    has_finish = any(pattern in text for pattern in finish_patterns)
    if has_finish:
        return "完成"
    if has_start:
        return "开始未完成"
    return "未出现"


def register_status(text):
    if text is None:
        return "日志未读取"
    found_signature = "Signature register stdout:" in text
    found_info = "PersonalInfo register stdout:" in text
    if found_signature and found_info:
        return "Signature + PersonalInfo"
    if found_signature:
        return "Signature"
    if found_info:
        return "PersonalInfo"
    return "未出现"


def query_status(text):
    if text is None:
        return "日志未读取"
    if "Signature query stdout:" in text and "exists true" in text:
        return "exists true"
    if "Signature query stdout:" in text:
        return "已查询"
    return "未出现"


def role_phase_rows():
    rows = []
    entries = role_log_entries()
    for name in sorted(entries, key=lambda item: (item.rstrip("0123456789"), int(re.search(r"\d+$", item).group()) if re.search(r"\d+$", item) else 0)):
        info = entries[name]
        log_path = info.get("path")
        text = text_if_exists(materialized_path(log_path)) if log_path else None
        rows.append([
            name,
            info.get("command"),
            log_path,
            info.get("sha256") or (sha256_if_exists(materialized_path(log_path)) if log_path else None),
            stage_status(text, ["Keygen phase is starting", "Keygen phase is staring"], ["Keygen phase is finished"]),
            stage_status(text, ["Join phase is starting"], ["Join phase is finished"]),
            stage_status(text, ["Revoke phase is starting"], ["Revoke phase is finished"]),
            stage_status(text, ["Sign phase is starting"], ["Sign phase is finished"]),
            query_status(text),
            stage_status(text, ["Open Phase is starting", "Open phase is starting"], ["Open phase is finished"]),
            register_status(text),
        ])
    return rows


def chain_result_rows():
    rows = []
    chain_results = manifest.get("chain_results")
    if isinstance(chain_results, dict):
        for key in sorted(chain_results, key=lambda item: int(re.search(r"\d+$", item).group()) if re.search(r"\d+$", item) else 0):
            item = chain_results[key]
            if not isinstance(item, dict):
                continue
            user_name = item.get("user_name") or key
            registers = item.get("registers") if isinstance(item.get("registers"), dict) else {}
            selects = item.get("selects") if isinstance(item.get("selects"), dict) else {}
            for contract_key, contract_label, select_key in [
                ("signature", "Signature", "signature_select"),
                ("personal_info", "PersonalInfo", "personal_info_select"),
            ]:
                register = registers.get(contract_key, {})
                select = selects.get(select_key, {})
                if register or select:
                    select_path = select.get("path")
                    rows.append([
                        user_name,
                        contract_label,
                        register.get("transaction_hash"),
                        register.get("block_number"),
                        register.get("ret"),
                        select.get("exists"),
                        select_path,
                        select.get("sha256") or (sha256_if_exists(materialized_path(select_path)) if select_path else None),
                    ])
    if rows:
        return rows

    for name, info in role_log_entries().items():
        if not name.startswith("user"):
            continue
        text = text_if_exists(materialized_path(info.get("path", ""))) if info.get("path") else None
        if not text:
            continue
        registers = parse_registers(text)
        for contract_key, contract_label in [("signature", "Signature"), ("personal_info", "PersonalInfo")]:
            register = registers.get(contract_key)
            if register:
                rows.append([
                    name,
                    contract_label,
                    register.get("transaction_hash"),
                    register.get("block_number"),
                    register.get("ret"),
                    None,
                    None,
                    None,
                ])
    return rows


def identity_rows():
    rows = []
    identity = manifest.get("identity")
    if isinstance(identity, dict):
        for key in sorted(identity, key=lambda item: int(re.search(r"\d+$", item).group()) if re.search(r"\d+$", item) else 0):
            item = identity[key]
            if isinstance(item, dict):
                output = item.get("output")
                rows.append([
                    key,
                    item.get("user_name"),
                    item.get("input"),
                    output,
                    item.get("sha256") or (sha256_if_exists(Path(output)) if output else None),
                ])
    return rows


def failure_hints():
    if manifest.get("success") is True:
        return []
    patterns = re.compile(r"(error|failed|timed out|panic|missing|required|port already in use|not found)", re.IGNORECASE)
    hints = []
    for label, item in artifacts.items():
        path_text = item.get("path")
        if not path_text:
            continue
        text = text_if_exists(materialized_path(path_text))
        if not text:
            continue
        for line in text.splitlines():
            stripped = line.strip()
            if stripped and patterns.search(stripped):
                hints.append((label, stripped))
    return hints[-10:]


def md_table(headers, rows):
    lines = []
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("| " + " | ".join("---" for _ in headers) + " |")
    if rows:
        for row in rows:
            lines.append("| " + " | ".join(table_cell(value) for value in row) + " |")
    else:
        lines.append("| " + " | ".join("-" for _ in headers) + " |")
    return "\n".join(lines)


success = manifest.get("success")
conclusion = "通过" if success is True else "失败" if success is False else "未知"
error_message = manifest.get("error")
chain = manifest.get("chain") if isinstance(manifest.get("chain"), dict) else {}
runtime = manifest.get("runtime") if isinstance(manifest.get("runtime"), dict) else {}
config = manifest.get("config") if isinstance(manifest.get("config"), dict) else {}
roles = manifest.get("roles") if isinstance(manifest.get("roles"), dict) else {}
git = manifest.get("git") if isinstance(manifest.get("git"), dict) else {}

lines = []
lines.append("# E2E（End-to-End，端到端）验收报告")
lines.append("")
lines.append("本报告由 `scripts/evidence/generate-e2e-report.sh` 从 Manifest（运行清单）和可读取日志生成，只记录摘要、路径和 SHA-256（安全哈希算法 256 位），不内嵌大日志。")
lines.append("")
lines.append("## 结论")
lines.append("")
lines.append(md_table(
    ["字段", "值"],
    [
        ["结论", conclusion],
        ["Manifest", code(manifest_path)],
        ["生成时间", dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")],
        ["Schema（结构版本）", code(manifest.get("schema_version"))],
        ["脚本版本", code(manifest.get("script_version"))],
        ["开始时间", code(manifest.get("start_timestamp"))],
        ["结束时间", code(manifest.get("end_timestamp"))],
        ["耗时秒数", manifest.get("elapsed_seconds")],
        ["失败原因", error_message if success is False else "-"],
        ["命令", code(manifest.get("command"))],
    ],
))
lines.append("")
lines.append("## 环境与运行目录")
lines.append("")
lines.append(md_table(
    ["字段", "值"],
    [
        ["Git（分布式版本控制系统）分支", code(git.get("branch"))],
        ["Git 提交", code(git.get("commit"))],
        ["Git 状态", code(git.get("status_short") or "clean")],
        ["runtime（运行时）目录", code(runtime.get("runtime_dir"))],
        ["state（状态）目录", code(runtime.get("state_dir"))],
        ["日志目录", code(runtime.get("log_dir") or str(log_dir))],
        ["配置模式", code(config.get("mode"))],
        ["runtime config（运行时配置）目录", code(config.get("runtime_config_dir"))],
        ["reuse-chain（复用链）", runtime.get("reuse_chain")],
        ["合约地址来自环境变量", runtime.get("contract_addresses_from_env")],
        ["FISCO BCOS（金融区块链合作联盟开源区块链底层平台）配置", code(chain.get("fisco_config"))],
        ["FISCO Group（组）", code(chain.get("fisco_group"))],
    ],
))
lines.append("")
ports = manifest.get("ports") if isinstance(manifest.get("ports"), dict) else {}
lines.append("## 拓扑与区块")
lines.append("")
lines.append(md_table(
    ["字段", "值"],
    [
        ["Proxy（代理）数量", roles.get("proxy")],
        ["Node（管理员节点）数量", roles.get("nodes")],
        ["User（用户）数量", roles.get("users")],
        ["监听主机", code(ports.get("host"))],
        ["Proxy 端口", ports.get("proxy")],
        ["Node 端口", ", ".join(str(v) for v in ports.get("nodes", [])) if isinstance(ports.get("nodes"), list) else None],
        ["User 端口", ", ".join(str(v) for v in ports.get("users", [])) if isinstance(ports.get("users"), list) else None],
        ["运行前区块高度", chain.get("block_before")],
        ["运行后区块高度", chain.get("block_after")],
    ],
))
lines.append("")
contracts = chain.get("contracts") if isinstance(chain.get("contracts"), dict) else {}
lines.append("## 合约地址")
lines.append("")
lines.append(md_table(
    ["合约", "地址"],
    [
        ["PersonalInfo", code(contracts.get("personal_info"))],
        ["Signature", code(contracts.get("signature"))],
    ],
))
lines.append("")
lines.append("## TX（Transaction，交易）与查询")
lines.append("")
lines.append(md_table(
    ["用户", "合约", "TX 哈希", "区块", "ret", "select exists", "select 日志", "select SHA-256"],
    [[row[0], row[1], code(row[2]), row[3], row[4], row[5], code(row[6]), code(row[7])] for row in chain_result_rows()],
))
lines.append("")
lines.append("## 身份密文")
lines.append("")
lines.append(md_table(
    ["用户序号", "用户名", "输入", "输出", "SHA-256"],
    [[row[0], code(row[1]), code(row[2]), code(row[3]), code(row[4])] for row in identity_rows()],
))
lines.append("")
lines.append("## Role（角色）阶段")
lines.append("")
lines.append(md_table(
    ["角色", "命令", "日志路径", "日志 SHA-256", "KeyGen（联合密钥生成）", "Join（用户加入）", "Revoke（撤销）", "Sign（签名）", "Verify（验证）查询", "Open（揭示）", "Register（登记）"],
    [[row[0], code(row[1]), code(row[2]), code(row[3]), row[4], row[5], row[6], row[7], row[8], row[9], row[10]] for row in role_phase_rows()],
))
lines.append("")
lines.append("## 日志与产物")
lines.append("")
artifact_rows = []
for label, item in sorted(artifacts.items()):
    artifact_rows.append([label, code(item.get("path")), code(item.get("sha256"))])
lines.append(md_table(["名称", "路径", "SHA-256"], artifact_rows))
if success is False:
    lines.append("")
    lines.append("## 失败线索")
    lines.append("")
    hints = failure_hints()
    if hints:
        lines.append(md_table(["来源", "日志行"], hints))
    else:
        lines.append("未从可读取日志中提取到额外失败线索。")
lines.append("")

output_path.parent.mkdir(parents=True, exist_ok=True)
with output_path.open("w", encoding="utf-8", newline="\n") as report:
    report.write("\n".join(lines))
print(f"reportPath {output_path}")
PY
