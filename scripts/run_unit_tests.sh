#!/usr/bin/env bash
set -euo pipefail

tests=(
    alu
    controller
    comparator
    exception_unit
    immediate_decoder
    register_file
    data_memory
    instruction_memory
)

for test in "${tests[@]}"; do
    make -f Makefile.unit clean TEST="$test"
    make -f Makefile.unit TEST="$test"
done

echo "All unit tests passed!"
