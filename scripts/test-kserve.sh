#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:18081}"

echo "==> KServe v1 predict (distilgpt2 text generation)"
curl -fsS "${BASE_URL}/v1/models/tiny-llm:predict" \
  -H "Content-Type: application/json" \
  -H "Host: tiny-llm-predictor.kserve-lab.svc.cluster.local" \
  -d '{
    "inputs": "Hello from Kubernetes"
  }' | (command -v jq >/dev/null && jq . || cat)

echo ""
echo "Done."
