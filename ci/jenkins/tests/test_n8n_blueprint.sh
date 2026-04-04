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
    ("Postgres Upsert", "Send Email"),
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

print("PASS: test_n8n_blueprint.sh")
PY
