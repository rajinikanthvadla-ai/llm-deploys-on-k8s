#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="llm-lab"

echo "==> Cleaning up lab resources"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "Deleting kind cluster: ${CLUSTER_NAME}"
  kind delete cluster --name "${CLUSTER_NAME}"
  echo "Cluster deleted."
else
  echo "Cluster '${CLUSTER_NAME}' not found. Skipping kind delete."
fi

echo ""
echo "Cleanup complete."
echo "To start again: ./scripts/run-lab.sh"
