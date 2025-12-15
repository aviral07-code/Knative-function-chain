#!/bin/bash
set -euo pipefail

# Wrapper around sustained-test.sh to run both medium and heavy loads.

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "${ROOT_DIR}"

# medium: 60s, 150 connections
./sustained-test.sh medium 60 100

# heavy: 120s, 300 connections
./sustained-test.sh heavy 60 150
