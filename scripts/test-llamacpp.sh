#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:18080}"

echo "==> Health"
curl -fsS "${BASE_URL}/health"
echo ""

echo "==> OpenAI-compatible chat completion"
curl -fsS "${BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tinyllama",
    "messages": [
      {"role": "user", "content": "Say hello in one short sentence."}
    ],
    "max_tokens": 64,
    "temperature": 0.7
  }' | (command -v jq >/dev/null && jq . || cat)

echo ""
echo "Done."
