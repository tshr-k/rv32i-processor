#!/usr/bin/env bash
set -euo pipefail

make clean ARCH=single_cycle
make ARCH=single_cycle

echo "All single-cycle tests passed!"
