#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="llm-lab"

echo "==> Creating kind cluster '${CLUSTER_NAME}' (Docker Desktop)"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "Cluster already exists. Skipping create."
else
  kind create cluster --config "${ROOT_DIR}/kind/cluster.yaml"
fi

echo "==> Loading llama.cpp image into kind"
docker pull ghcr.io/ggml-org/llama.cpp:server
kind load docker-image ghcr.io/ggml-org/llama.cpp:server --name "${CLUSTER_NAME}"

kubectl cluster-info --context "kind-${CLUSTER_NAME}"
kubectl get nodes -o wide

echo ""
echo "Host ports mapped:"
echo "  http://localhost:18080 -> llama.cpp (NodePort 30080)"
echo "  http://localhost:18081 -> KServe example (NodePort 30081, optional)"
