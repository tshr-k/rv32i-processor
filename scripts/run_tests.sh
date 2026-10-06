#!/usr/bin/env bash
set -euo pipefail

tests=(
    alu
    controller
    immediate_decoder
    register_file
)

for test in "${tests[@]}"; do
    make clean TEST="$test"
    make TEST="$test"
done

echo "All tests passed!"
