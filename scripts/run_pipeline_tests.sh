#!/usr/bin/env bash
set -euo pipefail

make clean ARCH=pipeline
make ARCH=pipeline

echo "All pipeline tests passed!"
