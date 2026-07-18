#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="kserve-lab"

echo "==> Deploying KServe InferenceService (distilgpt2)"
kubectl apply -f "${ROOT_DIR}/k8s/kserve/namespace.yaml"
kubectl apply -f "${ROOT_DIR}/k8s/kserve/inferenceservice.yaml"

echo "==> Waiting for InferenceService to become Ready (first pull can take several minutes)..."
kubectl -n "${NAMESPACE}" wait --for=condition=Ready inferenceservice/tiny-llm --timeout=20m

kubectl apply -f "${ROOT_DIR}/k8s/kserve/service-nodeport.yaml"
kubectl -n "${NAMESPACE}" get inferenceservice,svc,pods

echo ""
echo "KServe predictor exposed at: http://localhost:18081"
echo "Run: ./scripts/test-kserve.sh"
