#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="llm"

MODEL_URL="${MODEL_URL:-}"
LORA_URL="${LORA_URL:-}"

echo "==> Deploying llama.cpp server to kind"

docker pull ghcr.io/ggml-org/llama.cpp:server
kind load docker-image ghcr.io/ggml-org/llama.cpp:server --name llm-lab 2>/dev/null || true

kubectl apply -f "${ROOT_DIR}/k8s/llamacpp/namespace.yaml"
kubectl apply -f "${ROOT_DIR}/k8s/llamacpp/pvc.yaml"
kubectl apply -f "${ROOT_DIR}/k8s/llamacpp/configmap.yaml"

if [[ -n "${MODEL_URL}" ]]; then
  echo "Patching MODEL_URL: ${MODEL_URL}"
  kubectl -n "${NAMESPACE}" patch configmap llamacpp-config --type merge \
    -p "{\"data\":{\"MODEL_URL\":\"${MODEL_URL}\"}}"
fi

if [[ -n "${LORA_URL}" ]]; then
  echo "Patching LORA_URL: ${LORA_URL}"
  kubectl -n "${NAMESPACE}" patch configmap llamacpp-config --type merge \
    -p "{\"data\":{\"LORA_URL\":\"${LORA_URL}\"}}"
fi

kubectl apply -f "${ROOT_DIR}/k8s/llamacpp/deployment.yaml"
kubectl apply -f "${ROOT_DIR}/k8s/llamacpp/service.yaml"

echo "==> Waiting for pod (model download can take a few minutes)..."
kubectl -n "${NAMESPACE}" rollout status deployment/llamacpp --timeout=15m

kubectl -n "${NAMESPACE}" get pods,svc

echo ""
echo "Ready. Open: http://localhost:18080/health"
echo "Chat UI:  http://localhost:18080"
echo "Run:      ./scripts/test-llamacpp.sh"
