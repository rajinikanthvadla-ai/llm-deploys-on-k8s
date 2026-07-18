#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=========================================="
echo " LLM on Kubernetes: minimal kind lab"
echo "=========================================="

"${ROOT_DIR}/scripts/setup-kind.sh"
"${ROOT_DIR}/scripts/deploy-llamacpp.sh"
"${ROOT_DIR}/scripts/test-llamacpp.sh"

echo ""
echo "Optional KServe path:"
echo "  ./scripts/install-kserve.sh"
echo "  ./scripts/deploy-kserve.sh"
echo "  ./scripts/test-kserve.sh"
echo ""
echo "Cleanup:"
echo "  ./scripts/cleanup.sh"
