#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 LABEL"
  echo "Example: $0 burst1"
  exit 1
fi

LABEL=$1
POLICIES=("conc" "rps" "custom")
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "${ROOT_DIR}"

mkdir -p results

if [ -z "${NODE_IP:-}" ] || [ -z "${KOURIER_PORT:-}" ]; then
  echo "Set NODE_IP and KOURIER_PORT environment variables."
  exit 1
fi

URL="http://${NODE_IP}:${KOURIER_PORT}/"

for policy in "${POLICIES[@]}"; do
  OUT="results/burst-${LABEL}-${policy}.txt"
  HOST="func-a-${policy}.default.example.com"

  echo "=== Bursty traffic ${LABEL} for ${policy} ===" | tee "${OUT}"

  echo "--- Burst 1 ---" | tee -a "${OUT}"
  wrk -t8 -c200 -d30s --latency \
      -H "Host: ${HOST}" "${URL}" | tee -a "${OUT}"

  echo "--- Cooldown ---" | tee -a "${OUT}"
  sleep 60

  echo "--- Burst 2 ---" | tee -a "${OUT}"
  wrk -t8 -c200 -d30s --latency \
      -H "Host: ${HOST}" "${URL}" | tee -a "${OUT}"
done
