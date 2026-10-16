#!/usr/bin/env bash
set -euo pipefail

common_tests=(
    alu
    comparator
    controller
    machine_csr
    immediate_decoder
    register_file
    data_memory
)

single_cycle_tests=(
    single_cycle_exception_unit
    single_cycle_instruction_memory
)

pipeline_tests=(
    pipeline_icache
    pipeline_icache_controller
    pipeline_instruction_memory
)

for test in "${common_tests[@]}" "${single_cycle_tests[@]}" "${pipeline_tests[@]}"; do
    make clean TEST="$test"
    make TEST="$test"
done

# Parameter edge cases, as "<module> <parameter overrides>"
parametrised_tests=(
    "pipeline_icache NUM_LINES=2"
    "pipeline_instruction_memory LATENCY=1"
)

for entry in "${parametrised_tests[@]}"; do
    read -r test params <<< "$entry"
    make clean TEST="$test" PARAMS="$params"
    make TEST="$test" PARAMS="$params"
done

echo "All unit tests passed!"
