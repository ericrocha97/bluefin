#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/test_generate_metadata.sh"
bash "$SCRIPT_DIR/test_extract_versions.sh"
