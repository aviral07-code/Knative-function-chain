#!/bin/bash
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: $0 SCENARIO DURATION_SECONDS CONNECTIONS"
  echo "Example: $0 light 60 50"
  exit 1
fi

SCENARIO=$1    # light|medium|heavy
DURATION=$2
CONNS=$3

THREADS=4
POLICIES=("conc" "rps" "custom")
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "${ROOT_DIR}"

mkdir -p results

if [ -z "${NODE_IP:-}" ] || [ -z "${KOURIER_PORT:-}" ]; then
  echo "Set NODE_IP and KOURIER_PORT environment variables."
  exit 1
fi

for policy in "${POLICIES[@]}"; do
  OUT="sustained-${SCENARIO}-${policy}.txt"
  URL="http://${NODE_IP}:${KOURIER_PORT}/"
  HOST="func-a-${policy}.default.example.com"

  echo "=== Sustained ${SCENARIO} load for ${policy} ===" | tee "${OUT}"
  echo "wrk -t${THREADS} -c${CONNS} -d${DURATION}s" | tee -a "${OUT}"

  wrk -t${THREADS} -c${CONNS} -d${DURATION}s \
      --latency \
      -H "Host: ${HOST}" \
      "${URL}" | tee -a "${OUT}"
done
