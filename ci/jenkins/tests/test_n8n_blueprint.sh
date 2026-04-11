#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/assert.sh"

BLUEPRINT_FILE="$REPO_ROOT/n8n/blueprints/jenkins-build-events-workflow.json"

if [[ ! -f "$BLUEPRINT_FILE" ]]; then
    fail "Missing n8n blueprint file: $BLUEPRINT_FILE"
fi

python3 - "$BLUEPRINT_FILE" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

required_nodes = [
    "Webhook Trigger",
    "Validate Payload",
    "Postgres Upsert",
    "Set Public Build Link",
    "Build Email HTML",
    "Send Email",
    "Respond Success",
]

nodes = data.get("nodes")
if not isinstance(nodes, list):
    print("ASSERTION FAILED: blueprint nodes must be a list", file=sys.stderr)
    sys.exit(1)

node_names = {node.get("name") for node in nodes if isinstance(node, dict)}
for required in required_nodes:
    if required not in node_names:
        print(f"ASSERTION FAILED: missing node '{required}'", file=sys.stderr)
        sys.exit(1)

connections = data.get("connections")
if not isinstance(connections, dict):
    print("ASSERTION FAILED: blueprint connections must be an object", file=sys.stderr)
    sys.exit(1)

edges = set()
for source, source_payload in connections.items():
    main = source_payload.get("main", []) if isinstance(source_payload, dict) else []
    for lane in main:
        if not isinstance(lane, list):
            continue
        for target in lane:
            if isinstance(target, dict) and "node" in target:
                edges.add((source, target["node"]))

required_edges = [
    ("Webhook Trigger", "Validate Payload"),
    ("Validate Payload", "Postgres Upsert"),
    ("Postgres Upsert", "Set Public Build Link"),
    ("Set Public Build Link", "Build Email HTML"),
    ("Build Email HTML", "Send Email"),
    ("Send Email", "Respond Success"),
]

for edge in required_edges:
    if edge not in edges:
        print(
            f"ASSERTION FAILED: missing flow edge {edge[0]} -> {edge[1]}",
            file=sys.stderr,
        )
        sys.exit(1)

postgres_node = next(
    (node for node in nodes if isinstance(node, dict) and node.get("name") == "Postgres Upsert"),
    None,
)
if postgres_node is None:
    print("ASSERTION FAILED: missing Postgres Upsert node", file=sys.stderr)
    sys.exit(1)

params = postgres_node.get("parameters", {})
query = params.get("query") if isinstance(params, dict) else None
if not isinstance(query, str):
    print("ASSERTION FAILED: Postgres Upsert query must be a string", file=sys.stderr)
    sys.exit(1)

if "{{$json." in query:
    print(
        "ASSERTION FAILED: Postgres Upsert query contains unsafe interpolation pattern '{{$json.'",
        file=sys.stderr,
    )
    sys.exit(1)

required_returning_patterns = [
    "RETURNING id, job_name, build_number, status,",
    "build_url,",
    "git_sha,",
    "image_name,",
    "release_tag,",
    "started_at,",
    "finished_at,",
    "duration_ms,",
    "published_tags,",
    "payload->>'timestamp_utc' AS timestamp_utc,",
    "payload->>'error_summary' AS error_summary,",
]

for pattern in required_returning_patterns:
    if pattern not in query:
        print(
            f"ASSERTION FAILED: Postgres Upsert RETURNING missing pattern '{pattern}'",
            file=sys.stderr,
        )
        sys.exit(1)

validate_node = next(
    (node for node in nodes if isinstance(node, dict) and node.get("name") == "Validate Payload"),
    None,
)
if validate_node is None:
    print("ASSERTION FAILED: missing Validate Payload node", file=sys.stderr)
    sys.exit(1)

validate_params = validate_node.get("parameters", {})
validate_code = validate_params.get("jsCode") if isinstance(validate_params, dict) else None
if not isinstance(validate_code, str):
    print("ASSERTION FAILED: Validate Payload jsCode must be a string", file=sys.stderr)
    sys.exit(1)

required_validate_patterns = [
    "x-jenkins-webhook-token",
    "N8N_WEBHOOK_SHARED_TOKEN",
]

for pattern in required_validate_patterns:
    if pattern not in validate_code:
        print(
            f"ASSERTION FAILED: Validate Payload jsCode missing pattern '{pattern}'",
            file=sys.stderr,
        )
        sys.exit(1)

set_public_link_node = next(
    (node for node in nodes if isinstance(node, dict) and node.get("name") == "Set Public Build Link"),
    None,
)
if set_public_link_node is None:
    print("ASSERTION FAILED: missing Set Public Build Link node", file=sys.stderr)
    sys.exit(1)

set_public_link_params = set_public_link_node.get("parameters", {})
set_public_link_code = (
    set_public_link_params.get("jsCode") if isinstance(set_public_link_params, dict) else None
)
if not isinstance(set_public_link_code, str):
    print("ASSERTION FAILED: Set Public Build Link jsCode must be a string", file=sys.stderr)
    sys.exit(1)

required_public_link_patterns = [
    "JENKINS_PUBLIC_URL",
    "http://casaos.local:18080/",
    "link:",
]

for pattern in required_public_link_patterns:
    if pattern not in set_public_link_code:
        print(
            f"ASSERTION FAILED: Set Public Build Link jsCode missing pattern '{pattern}'",
            file=sys.stderr,
        )
        sys.exit(1)

build_email_html_node = next(
    (node for node in nodes if isinstance(node, dict) and node.get("name") == "Build Email HTML"),
    None,
)
if build_email_html_node is None:
    print("ASSERTION FAILED: missing Build Email HTML node", file=sys.stderr)
    sys.exit(1)

build_email_html_params = build_email_html_node.get("parameters", {})
build_email_html_code = (
    build_email_html_params.get("jsCode") if isinstance(build_email_html_params, dict) else None
)
if not isinstance(build_email_html_code, str):
    print("ASSERTION FAILED: Build Email HTML jsCode must be a string", file=sys.stderr)
    sys.exit(1)

required_email_html_patterns = [
    "<!doctype html>",
    "Notificacao de Build",
    "Sem erros reportados.",
    "email_html",
]

for pattern in required_email_html_patterns:
    if pattern not in build_email_html_code:
        print(
            f"ASSERTION FAILED: Build Email HTML jsCode missing pattern '{pattern}'",
            file=sys.stderr,
        )
        sys.exit(1)

send_email_node = next(
    (node for node in nodes if isinstance(node, dict) and node.get("name") == "Send Email"),
    None,
)
if send_email_node is None:
    print("ASSERTION FAILED: missing Send Email node", file=sys.stderr)
    sys.exit(1)

send_email_params = send_email_node.get("parameters", {})
if not isinstance(send_email_params, dict):
    print("ASSERTION FAILED: Send Email parameters must be an object", file=sys.stderr)
    sys.exit(1)

send_email_html = send_email_params.get("html")
if not isinstance(send_email_html, str):
    print("ASSERTION FAILED: Send Email html must be a string", file=sys.stderr)
    sys.exit(1)

if send_email_html.strip() != "={{$json.email_html}}":
    print(
        "ASSERTION FAILED: Send Email html must reference $json.email_html",
        file=sys.stderr,
    )
    sys.exit(1)

print("PASS: test_n8n_blueprint.sh")
PY
