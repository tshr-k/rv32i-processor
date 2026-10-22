#!/usr/bin/env bash
set -euo pipefail

make clean ARCH=single_cycle
make ARCH=single_cycle
make ARCH=single_cycle SPIKE=1

echo "All single-cycle tests passed!"
