#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

python_bin="${PYTHON_BIN:-python3}"
if ! command -v "$python_bin" >/dev/null 2>&1 || ! "$python_bin" -c 'import json' >/dev/null 2>&1; then
  python_bin="python"
fi
if ! command -v "$python_bin" >/dev/null 2>&1 || ! "$python_bin" -c 'import json' >/dev/null 2>&1; then
  echo "Required command not found: python3 or python" >&2
  exit 2
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/gstbk-evidence-json.XXXXXX")"
if [ "${GSTBK_KEEP_SELF_TEST_OUTPUT:-}" != "1" ]; then
  trap 'rm -rf "$tmp_dir"' EXIT
fi

host_path() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -a "$path"
  elif command -v realpath >/dev/null 2>&1; then
    realpath -m "$path"
  else
    printf '%s\n' "$path"
  fi
}

mkdir -p "$tmp_dir/logs"
manifest_path="$tmp_dir/manifest.json"
node_log="$tmp_dir/logs/node1.out"
node_file_log="$tmp_dir/logs/node1.log4rs.log"

cat >"$node_log" <<'EOF'
Signature query stdout:
exists true
User 1 Node::verify_phase() : invalid signature
Open Phase is starting
Open phase is finished!
User 2 Node::verify_phase() : verify successfully
EOF

cat >"$node_file_log" <<'EOF'
2026-05-12T15:38:25Z INFO node::gs_tbk_scheme::open_phase - This user 1 maybe used a invaild key!
2026-05-12T15:38:25Z INFO node::gs_tbk_scheme::open_phase - This user 1 maybe malicious!
2026-05-12T15:38:25Z INFO node::gs_tbk_scheme::open_phase - user_id:1
2026-05-12T15:38:25Z INFO node::gs_tbk_scheme::open_phase - user_name:evidence_user1
2026-05-12T15:38:25Z INFO node::gs_tbk_scheme::open_phase - user address:127.0.0.1:60001
EOF

manifest_host="$(host_path "$manifest_path")"
log_dir_host="$(host_path "$tmp_dir/logs")"
node_log_host="$(host_path "$node_log")"
node_file_log_host="$(host_path "$node_file_log")"
node_sha="$("$python_bin" -c 'import hashlib, pathlib, sys; print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())' "$node_log_host")"
node_file_sha="$("$python_bin" -c 'import hashlib, pathlib, sys; print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())' "$node_file_log_host")"

GSTBK_SELF_TEST_MANIFEST="$manifest_host" \
GSTBK_SELF_TEST_LOG_DIR="$log_dir_host" \
GSTBK_SELF_TEST_NODE_LOG="$node_log_host" \
GSTBK_SELF_TEST_NODE_SHA="$node_sha" \
GSTBK_SELF_TEST_NODE_FILE_LOG="$node_file_log_host" \
GSTBK_SELF_TEST_NODE_FILE_SHA="$node_file_sha" \
  "$python_bin" <<'PY'
import json
import os
from pathlib import Path


manifest = {
    "success": True,
    "command": "fixture self-test",
    "runtime": {
        "log_dir": os.environ["GSTBK_SELF_TEST_LOG_DIR"],
    },
    "chain": {
        "contracts": {
            "signature": "0xSIGNATURE_FIXTURE",
            "personal_info": "0xPERSONAL_INFO_FIXTURE",
        },
    },
    "roles": {
        "logs": {
            "node1": {
                "path": os.environ["GSTBK_SELF_TEST_NODE_LOG"],
                "sha256": os.environ["GSTBK_SELF_TEST_NODE_SHA"],
                "file_log_path": os.environ["GSTBK_SELF_TEST_NODE_FILE_LOG"],
                "file_log_sha256": os.environ["GSTBK_SELF_TEST_NODE_FILE_SHA"],
            },
        },
    },
    "identity": {
        "user1": {
            "sha256": "1111111111111111111111111111111111111111111111111111111111111111",
        },
        "user2": {
            "sha256": "2222222222222222222222222222222222222222222222222222222222222222",
        },
    },
    "chain_results": {
        "user1": {
            "user_name": "evidence_user1",
            "registers": {
                "signature": {
                    "transaction_hash": "0xaaa111",
                    "block_number": "11",
                    "ret": "0",
                },
                "personal_info": {
                    "transaction_hash": "0xbbb111",
                    "block_number": "13",
                    "ret": "0",
                },
            },
            "selects": {
                "signature_select": {
                    "exists": True,
                    "path": "chain/user1-signature.out",
                    "sha256": "siguser1",
                },
                "personal_info_select": {
                    "exists": True,
                    "path": "chain/user1-info.out",
                    "sha256": "infouser1",
                },
            },
        },
        "user2": {
            "user_name": "evidence_user2",
            "registers": {
                "signature": {
                    "transaction_hash": "0xaaa222",
                    "block_number": "12",
                    "ret": "0",
                },
                "personal_info": {
                    "transaction_hash": "0xbbb222",
                    "block_number": "14",
                    "ret": "0",
                },
            },
            "selects": {
                "signature_select": {
                    "exists": True,
                    "path": "chain/user2-signature.out",
                    "sha256": "siguser2",
                },
                "personal_info_select": {
                    "exists": True,
                    "path": "chain/user2-info.out",
                    "sha256": "infouser2",
                },
            },
        },
    },
}

Path(os.environ["GSTBK_SELF_TEST_MANIFEST"]).write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

audit_explicit_dir="$tmp_dir/audit-explicit"
audit_default_dir="$tmp_dir/audit-default"
malicious_explicit_dir="$tmp_dir/malicious-explicit"
malicious_default_dir="$tmp_dir/malicious-default"
audit_explicit_json="$audit_explicit_dir/custom-audit.json"
malicious_explicit_json="$malicious_explicit_dir/custom-malicious.json"

bash "$repo_root/scripts/evidence/run-audit-query-demo.sh" \
  --manifest "$manifest_path" \
  --output-dir "$audit_explicit_dir" \
  --json-output "$audit_explicit_json" \
  --dry-run >/dev/null

bash "$repo_root/scripts/evidence/run-audit-query-demo.sh" \
  --manifest "$manifest_path" \
  --output-dir "$audit_default_dir" \
  --dry-run >/dev/null

bash "$repo_root/scripts/evidence/run-malicious-open-demo.sh" \
  --manifest "$manifest_path" \
  --output-dir "$malicious_explicit_dir" \
  --json-output "$malicious_explicit_json" >/dev/null

bash "$repo_root/scripts/evidence/run-malicious-open-demo.sh" \
  --manifest "$manifest_path" \
  --output-dir "$malicious_default_dir" >/dev/null

refresh_target_dir="$tmp_dir/console-evidence"
bash "$repo_root/scripts/evidence/refresh-audit-console-evidence.sh" \
  --manifest "$manifest_path" \
  --target-dir "$refresh_target_dir" \
  --dry-run-audit \
  --no-check >/dev/null

"$python_bin" - "$audit_explicit_json" \
  "$audit_default_dir/audit-query-summary.json" \
  "$malicious_explicit_json" \
  "$malicious_default_dir/malicious-open-summary.json" \
  "$refresh_target_dir/console-current-audit-query.json" \
  "$refresh_target_dir/console-current-malicious-open.json" <<'PY'
import json
import sys
from pathlib import Path


required = {
    "generated_at",
    "manifest",
    "output_dir",
    "success",
    "users",
    "contract_addresses",
    "tx_hashes",
    "block_numbers",
    "query_results",
    "verify_open_status",
    "log_sha256",
    "notes",
}

paths = [Path(value) for value in sys.argv[1:]]
audit_paths = [paths[0], paths[1], paths[4]]
malicious_paths = [paths[2], paths[3], paths[5]]
for path in paths:
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = required - data.keys()
    if missing:
        raise SystemExit(f"{path} is missing JSON keys: {sorted(missing)}")
    if data["success"] is not True:
        raise SystemExit(f"{path} did not report success true")
    markdown_summary = Path(data["markdown_summary"])
    if not markdown_summary.is_file():
        raise SystemExit(f"{path} did not generate Markdown summary: {markdown_summary}")

for path in audit_paths:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not data["query_results"]:
        raise SystemExit(f"{path} has no audit query_results")
    if {row["status"] for row in data["query_results"]} != {"dry-run"}:
        raise SystemExit(f"{path} audit rows were not dry-run only")

for path in malicious_paths:
    data = json.loads(path.read_text(encoding="utf-8"))
    role_logs = data["verify_open_status"]["role_logs"]
    user1 = next(item for item in role_logs if item["manifest_user"] == "user1")
    user2 = next(item for item in role_logs if item["manifest_user"] == "user2")
    if user1["verify_status"] != "failed_triggers_open":
        raise SystemExit(f"{path} did not mark user1 as failed_triggers_open")
    if user1["open_triggered_by_user"] is not True:
        raise SystemExit(f"{path} did not mark user1 as the Open trigger")
    fields = user1["reveal_fields"]
    if fields["user_id"] != "1" or fields["user_name"] != "evidence_user1":
        raise SystemExit(f"{path} did not capture structured user1 reveal fields: {fields}")
    if fields["address"] != "127.0.0.1:60001":
        raise SystemExit(f"{path} did not capture user1 reveal address: {fields}")
    if "user address:127.0.0.1:60001" not in user1["reveal"]:
        raise SystemExit(f"{path} did not include the reveal address in Markdown-ready text")
    if not any(source["kind"] == "log4rs_file" for source in user1["log_sources"]):
        raise SystemExit(f"{path} did not preserve the log4rs file source")
    if user2["verify_status"] != "passed":
        raise SystemExit(f"{path} did not mark user2 as passed")
    if user2["open_status"] != "global_completed_not_triggered_by_user":
        raise SystemExit(f"{path} did not preserve user2 global Open semantics")
    if user2["open_triggered_by_user"] is not False:
        raise SystemExit(f"{path} incorrectly marked user2 as the Open trigger")
    markdown = Path(data["markdown_summary"]).read_text(encoding="utf-8")
    if "user_name:evidence_user1" not in markdown or "user address:127.0.0.1:60001" not in markdown:
        raise SystemExit(f"{path} Markdown summary did not include reveal fields")

print("self-test JSON summaries parsed and validated")
PY

echo "self-test output: $tmp_dir"
