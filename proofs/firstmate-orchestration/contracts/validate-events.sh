#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVENTS_FILE="$SCRIPT_DIR/events.json"

python3 - "$EVENTS_FILE" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
doc = json.loads(path.read_text(encoding="utf-8"))

current_expected = {
    "intent.accepted",
    "wayfinder.ready-leaf.selected",
    "front.scope-routed",
    "worker.isolated",
    "supervision.wake-reconciled",
    "delivery.guarded",
    "learning.capture.terminal",
}
planned_expected = {
    "compounding.cut-marked",
    "compounding.watcher-external",
    "compounding.claim-candidate",
    "compounding.write-decision",
    "compounding.provenance-recorded",
    "compounding.canonical-artifact",
    "compounding.derived-index-rebuilt",
    "compounding.brief-bounded",
}
required_outcomes = {
    "skill",
    "/knowledge",
    "project-owner",
    "task report",
    "no-new-learning",
}
required_captain = {
    "strategy",
    "scope-expansion",
    "destructive-or-irreversible-action",
    "security-sensitive-choice",
    "private-publication",
    "required-visual-review",
}
required_worker_blocks = {
    "set-strategy",
    "expand-scope",
    "approve-own-delivery",
    "publish-private-material",
}


def fail(message: str) -> None:
    raise SystemExit(f"contract: FAIL: {message}")


def rows(key: str) -> list[dict]:
    value = doc.get(key)
    if not isinstance(value, list) or not value:
        fail(f"{key} must be a non-empty list")
    if any(not isinstance(row, dict) for row in value):
        fail(f"{key} must contain objects")
    return value


def unique_types(items: list[dict], key: str) -> set[str]:
    types = [item.get("type") for item in items]
    if any(not isinstance(item_type, str) or not item_type for item_type in types):
        fail(f"{key} contains an event without a type")
    if len(types) != len(set(types)):
        fail(f"{key} contains duplicate event types")
    return set(types)


current = rows("current_events")
planned = rows("planned_events")
current_types = unique_types(current, "current_events")
planned_types = unique_types(planned, "planned_events")

if current_types != current_expected:
    fail(f"current event set differs: {sorted(current_types ^ current_expected)}")
if planned_types != planned_expected:
    fail(f"planned event set differs: {sorted(planned_types ^ planned_expected)}")

for item in current:
    if item.get("maturity") != "current":
        fail(f"current event is not marked current: {item['type']}")
for item in planned:
    if item.get("maturity") != "planned":
        fail(f"planned event is not marked planned: {item['type']}")

learning = next(item for item in current if item["type"] == "learning.capture.terminal")
if set(learning.get("outcomes", [])) != required_outcomes:
    fail("terminal capture outcomes do not cover every owner and no-new-learning")

write_decision = next(item for item in planned if item["type"] == "compounding.write-decision")
if set(write_decision.get("dispositions", [])) != {
    "reject",
    "enrich",
    "related new",
    "supersede",
    "consolidate",
}:
    fail("planned write decision set is incomplete")

claim = next(item for item in planned if item["type"] == "compounding.claim-candidate")
if set(claim.get("claim_kinds", [])) != {"Decision", "Constraint", "Failure", "Module"}:
    fail("planned Claim kinds are incomplete")

if set(doc.get("authority", {}).get("captain_only", [])) != required_captain:
    fail("captain-only authority boundary is incomplete")
if set(doc.get("authority", {}).get("worker_cannot", [])) != required_worker_blocks:
    fail("worker authority boundary is incomplete")
if set(doc.get("authority", {}).get("wayfinder_can", [])) != {
    "record-map",
    "route-ready-leaf",
}:
    fail("Wayfinder allowed actions are incomplete")
if set(doc.get("authority", {}).get("wayfinder_cannot", [])) != {
    "execute-work",
    "grant-authority",
}:
    fail("Wayfinder forbidden actions are incomplete")

serialized = json.dumps(doc, ensure_ascii=False)
private_patterns = [
    re.escape("/" + "home" + "/"),
    re.escape("/" + "Users" + "/"),
    r"[A-Za-z]:[\\/]",
    re.escape("gh" + "p_"),
    re.escape("sk" + "-"),
    re.escape("BEGIN " + "RSA"),
    re.escape("AKIA"),
    re.escape("xox"),
]
for pattern in private_patterns:
    if re.search(pattern, serialized, re.IGNORECASE):
        fail("fixture matches a publication-blocking pattern")

print(
    "contract: ok "
    f"current={len(current)} planned={len(planned)} "
    "authority=explicit learning=owner-or-none"
)
PY
