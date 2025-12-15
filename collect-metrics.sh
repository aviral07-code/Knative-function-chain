#!/bin/bash

POLICY=$1
OUTPUT_FILE=$2
DURATION=$3  # seconds

if [ -z "$POLICY" ] || [ -z "$OUTPUT_FILE" ] || [ -z "$DURATION" ]; then
  echo "Usage: $0 [policy] [output_file] [duration_seconds]"
  echo "Example: $0 conc metrics-conc.csv 120"
  exit 1
fi

echo "Collecting metrics for policy: $POLICY"
echo "Output file: $OUTPUT_FILE"
echo "Duration: ${DURATION}s"
echo ""

# CSV header
echo "timestamp,function,replica_count" > $OUTPUT_FILE

END_TIME=$(($(date +%s) + DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
  TIMESTAMP=$(date +%s)
  
  # Get replica counts for each function
  for FUNC in a b c; do
    COUNT=$(kubectl get pods -n default 2>/dev/null | \
      grep "func-${FUNC}-${POLICY}-00" | \
      grep -c "Running" || echo "0")
    
    echo "${TIMESTAMP},func-${FUNC}-${POLICY},${COUNT}" >> $OUTPUT_FILE
  done
  
  sleep 2
done

echo ""
echo "Metrics collection completed"
echo "Data saved to: $OUTPUT_FILE"