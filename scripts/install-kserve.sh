#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KSERVE_VERSION="${KSERVE_VERSION:-0.13.0}"

echo "==> Installing KServe ${KSERVE_VERSION} (serverless mode, ~3-5 min)"
kubectl apply -f "https://github.com/kserve/kserve/releases/download/v${KSERVE_VERSION}/kserve.yaml"
kubectl apply -f "https://github.com/kserve/kserve/releases/download/v${KSERVE_VERSION}/kserve-cluster-resources.yaml"

echo "==> Waiting for kserve-controller-manager"
kubectl -n kserve wait --for=condition=Available deployment/kserve-controller-manager --timeout=10m

echo "KServe installed."
