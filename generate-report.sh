#!/bin/bash
set -euo pipefail

echo "========================================="
echo "Knative Autoscaling Comparison Report"
echo "Generated: $(date)"
echo "========================================="
echo ""

POLICIES=("conc" "rps" "custom")
SCENARIOS=("light" "medium" "heavy")

mkdir -p results

echo "=== Performance Summary (sustained) ==="
echo ""

echo "scenario,policy,throughput_req_per_s,p99_latency_value" \
  > results/summary.csv

for scenario in "${SCENARIOS[@]}"; do
  for policy in "${POLICIES[@]}"; do
    FILE="results/sustained-${scenario}-${policy}.txt"
    if [ ! -f "${FILE}" ]; then
      continue
    fi
    THROUGHPUT=$(grep "Requests/sec:" "${FILE}" | awk '{print $2}')
    P99=$(grep "99.000%" "${FILE}" | awk '{print $2}')
    printf "%-8s %-8s %-12s %-12s\n" \
      "${scenario}" "${policy}" "${THROUGHPUT:-NA}" "${P99:-NA}"
    echo "${scenario},${policy},${THROUGHPUT:-NA},${P99:-NA}" \
      >> results/summary.csv
  done
done

echo ""
echo "=== Cold Start Comparison ==="
echo ""

for policy in "${POLICIES[@]}"; do
  FILE="results/coldstart-${policy}.txt"
  if [ ! -f "${FILE}" ]; then
    continue
  fi
  COLD=$(grep "Cold start time:" "${FILE}" | awk '{print $4}' | sed 's/s//')
  echo "${policy}: ${COLD}s"
done

echo ""
echo "=== Propagation Delay Coefficient (PDC) ==="
echo ""

for scenario in "${SCENARIOS[@]}"; do
  for policy in "${POLICIES[@]}"; do
    METRICS="results/metrics-sustained-${scenario}-${policy}.csv"
    if [ ! -f "${METRICS}" ]; then
      continue
    fi
    echo "--- ${scenario} / ${policy} ---"
    python3 calculate-pdc.py "${METRICS}"
  done
done

echo ""
echo "========================================="
echo "Detailed raw results in: $(pwd)/results/"
echo "Summary CSV: results/summary.csv"
echo "========================================="
