#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
sample_path="${1:-$repo_root/examples/evidence/events.sample.json}"

python_bin="${PYTHON_BIN:-python3}"
if ! command -v "$python_bin" >/dev/null 2>&1 || ! "$python_bin" -c 'import json' >/dev/null 2>&1; then
  python_bin="python"
fi
if ! command -v "$python_bin" >/dev/null 2>&1 || ! "$python_bin" -c 'import json' >/dev/null 2>&1; then
  echo "Required command not found: python3 or python" >&2
  exit 2
fi

"$python_bin" - "$sample_path" <<'PY'
import json
import sys
from datetime import datetime
from pathlib import Path


sample = Path(sys.argv[1])
data = json.loads(sample.read_text(encoding="utf-8"))

if data.get("schema_version") != "gstbk.evidence.events.v1":
    raise SystemExit("schema_version must be gstbk.evidence.events.v1")


def parse_utc(value: str, field: str) -> None:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise SystemExit(f"{field} must be a UTC timestamp ending with Z")
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise SystemExit(f"{field} is not ISO-8601: {value}") from exc


parse_utc(data.get("generated_at"), "generated_at")

source_summaries = data.get("source_summaries")
if not isinstance(source_summaries, list):
    raise SystemExit("source_summaries must be a list")

summary_core_fields = {
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

for source in source_summaries:
    for key in ("source_type", "path", "preserved_fields"):
        if key not in source:
            raise SystemExit(f"source_summaries[] missing {key}: {source}")
    if source["source_type"] in {"audit_query_summary", "malicious_open_summary"}:
        missing = summary_core_fields - set(source["preserved_fields"])
        if missing:
            raise SystemExit(
                f"{source['source_type']} did not preserve existing JSON fields: {sorted(missing)}"
            )

events = data.get("events")
if not isinstance(events, list) or not events:
    raise SystemExit("events must be a non-empty list")

required_event_fields = {
    "event_id",
    "event_type",
    "timestamp",
    "source",
    "actor",
    "target",
    "chain",
    "status",
    "evidence_refs",
    "risk_level",
    "summary",
}
required_event_types = {"audit_query", "malicious_open", "failure_scenario"}
risk_levels = {"info", "low", "medium", "high", "critical"}
status_by_type = {
    "audit_query": {"confirmed", "partial", "failed", "dry_run"},
    "malicious_open": {"open_completed", "open_started", "verify_passed_control", "inconclusive"},
    "failure_scenario": {"expected_failure", "recovered", "blocked", "inconclusive"},
}

seen_ids = set()
seen_types = set()

for event in events:
    missing = required_event_fields - event.keys()
    if missing:
        raise SystemExit(f"event missing fields {sorted(missing)}: {event.get('event_id')}")

    event_id = event["event_id"]
    if not isinstance(event_id, str) or not event_id:
        raise SystemExit("event_id must be a non-empty string")
    if event_id in seen_ids:
        raise SystemExit(f"duplicate event_id: {event_id}")
    seen_ids.add(event_id)

    event_type = event["event_type"]
    if event_type not in required_event_types:
        raise SystemExit(f"unsupported event_type: {event_type}")
    seen_types.add(event_type)
    if event["status"] not in status_by_type[event_type]:
        raise SystemExit(f"{event_id} has invalid status for {event_type}: {event['status']}")
    if event["risk_level"] not in risk_levels:
        raise SystemExit(f"{event_id} has invalid risk_level: {event['risk_level']}")
    if not isinstance(event["summary"], str) or not event["summary"]:
        raise SystemExit(f"{event_id} summary must be non-empty")

    parse_utc(event["timestamp"], f"{event_id}.timestamp")

    for obj_name in ("source", "actor", "target", "chain"):
        if not isinstance(event[obj_name], dict):
            raise SystemExit(f"{event_id}.{obj_name} must be an object")

    if not event["source"].get("kind") or not event["source"].get("name"):
        raise SystemExit(f"{event_id}.source must include kind and name")
    if not event["actor"].get("role") or not event["actor"].get("id"):
        raise SystemExit(f"{event_id}.actor must include role and id")
    if not event["target"].get("kind"):
        raise SystemExit(f"{event_id}.target must include kind")
    if event["chain"].get("platform") != "FISCO BCOS":
        raise SystemExit(f"{event_id}.chain.platform must be FISCO BCOS")

    refs = event["evidence_refs"]
    if not isinstance(refs, list) or not refs:
        raise SystemExit(f"{event_id}.evidence_refs must be a non-empty list")
    for ref in refs:
        if not isinstance(ref, dict) or not ref.get("kind") or not ref.get("path"):
            raise SystemExit(f"{event_id} has invalid evidence_ref: {ref}")

    if event_type == "audit_query":
        queries = event["chain"].get("queries")
        if not isinstance(queries, list) or not queries:
            raise SystemExit(f"{event_id} audit_query must include chain.queries")
        if not any(query.get("query") == "select" and query.get("exists") is True for query in queries):
            raise SystemExit(f"{event_id} audit_query must include a successful select query")
        if not event["target"].get("contract_name"):
            raise SystemExit(f"{event_id} audit_query target must include contract_name")

    if event_type == "malicious_open":
        reveal = event["target"].get("reveal_fields")
        if not isinstance(reveal, dict):
            raise SystemExit(f"{event_id} malicious_open must include reveal_fields")
        for key in ("user_id", "user_name", "address"):
            if not reveal.get(key):
                raise SystemExit(f"{event_id} reveal_fields missing {key}")
        contracts = {record.get("contract_name") for record in event["chain"].get("records", [])}
        if {"Signature", "PersonalInfo"} - contracts:
            raise SystemExit(f"{event_id} malicious_open must reference Signature and PersonalInfo records")

    if event_type == "failure_scenario":
        if not event["target"].get("failure_code"):
            raise SystemExit(f"{event_id} failure_scenario must include failure_code")
        if event["chain"].get("tx_hash") is not None:
            raise SystemExit(f"{event_id} failure_scenario fixture should not have a tx_hash")

missing_types = required_event_types - seen_types
if missing_types:
    raise SystemExit(f"sample does not cover event types: {sorted(missing_types)}")

print(f"event schema self-test passed: {sample}")
PY
