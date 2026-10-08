#!/usr/bin/env bash
set -euo pipefail

common_tests=(
    alu
    comparator
    immediate_decoder
    register_file
    data_memory
    instruction_memory
)

single_cycle_tests=(
    single_cycle_controller
    single_cycle_exception_unit
)

for test in "${common_tests[@]}" "${single_cycle_tests[@]}"; do
    make clean TEST="$test"
    make TEST="$test"
done

echo "All unit tests passed!"
