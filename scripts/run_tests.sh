#!/usr/bin/env bash
set -euo pipefail

tests=(
    alu
    controller
    immediate_decoder
)

for test in "${tests[@]}"; do
    make clean TEST="$test"
    make TEST="$test"
done
