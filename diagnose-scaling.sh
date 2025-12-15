#!/bin/bash

echo "=== Scaling Diagnostic ==="
echo ""

echo "1. Current Pod Autoscaler Status:"
kubectl get podautoscalers.autoscaling.internal.knative.dev -n default -o wide

echo ""
echo "2. Current Replica Counts:"
for policy in conc rps custom; do
  echo "  Policy: $policy"
  for func in a b c; do
    COUNT=$(kubectl get pods -n default 2>/dev/null | grep "func-${func}-${policy}" | grep -c Running)
    echo "    func-${func}-${policy}: $COUNT pods"
  done
done

echo ""
echo "3. Autoscaling Configuration:"
kubectl get ksvc -n default -o custom-columns=\
NAME:.metadata.name,\
METRIC:.spec.template.metadata.annotations.autoscaling\\.knative\\.dev/metric,\
TARGET:.spec.template.metadata.annotations.autoscaling\\.knative\\.dev/target,\
MIN:.spec.template.metadata.annotations.autoscaling\\.knative\\.dev/min-scale,\
MAX:.spec.template.metadata.annotations.autoscaling\\.knative\\.dev/max-scale

echo ""
echo "4. Node Resource Usage:"
kubectl top nodes

echo ""
echo "=== End Diagnostic ==="