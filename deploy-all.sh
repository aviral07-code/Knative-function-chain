#!/bin/bash

set -euo pipefail

# Ensure DOCKER_USER is set (Docker Hub username)
if [ -z "${DOCKER_USER:-}" ]; then
  echo "Set DOCKER_USER to your Docker Hub username, e.g.:"
  echo "  export DOCKER_USER=aviralgarg007"
  exit 1
fi

# Move to repo root (scripts/../)
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "${ROOT_DIR}"

# Optionally keep generated manifests in a subdir
mkdir -p manifests-generated

# Replace YOUR_DOCKER_USER in each chain file and apply
for chain in concurrency rps custom; do
  SRC="chain-${chain}.yaml"
  DST="chain-${chain}-deploy.yaml"

  if [ ! -f "${SRC}" ]; then
    echo "Missing ${SRC} in ${ROOT_DIR}"
    exit 1
  fi

  sed "s/aviralgarg007/${DOCKER_USER}/g" "${SRC}" > "${DST}"
  echo "Applying ${DST}..."
  kubectl apply -f "${DST}"
done

# Wait for all 9 Knative services to be Ready
kubectl wait --for=condition=ready ksvc \
  func-a-conc func-b-conc func-c-conc \
  func-a-rps  func-b-rps  func-c-rps  \
  func-a-custom func-b-custom func-c-custom \
  --timeout=300s

echo ""
echo "Current Knative services:"
kubectl get ksvc
