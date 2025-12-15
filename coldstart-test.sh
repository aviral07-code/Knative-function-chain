#!/bin/bash
set -euo pipefail

POLICIES=("conc" "rps" "custom")
DRAIN_SECONDS=60
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "${ROOT_DIR}"

mkdir -p results

if [ -z "${NODE_IP:-}" ] || [ -z "${KOURIER_PORT:-}" ]; then
  echo "Set NODE_IP and KOURIER_PORT environment variables."
  exit 1
fi

for policy in "${POLICIES[@]}"; do
  OUT="results/coldstart-${policy}.txt"
  echo "=== Cold start test for ${policy} ===" | tee "${OUT}"
  echo "Waiting ${DRAIN_SECONDS}s for scale-to-zero..." | tee -a "${OUT}"
  sleep "${DRAIN_SECONDS}"

  START=$(date +%s.%N)
  curl -sS -H "Host: func-a-${policy}.default.example.com" \
       "http://${NODE_IP}:${KOURIER_PORT}/" \
       -w "\nHTTP %{http_code}\n" \
       -o "results/coldstart-${policy}-response.json" \
       | tee -a "${OUT}"
  END=$(date +%s.%N)

  ELAPSED=$(python3 - <<EOF
start=${START}
end=${END}
print(f"{end-start:.3f}")
EOF
)

echo "Cold start time: ${ELAPSED}s" | tee -a "${OUT}"
done
