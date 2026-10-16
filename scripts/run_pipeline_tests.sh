#!/usr/bin/env bash
set -euo pipefail

# Instruction memory latencies and cache sizes, where two lines forces frequent conflict misses
param_sets=(
    ""
    "INSTR_MEM_LATENCY=1"
    "INSTR_MEM_LATENCY=1 ICACHE_NUM_LINES=2"
    "INSTR_MEM_LATENCY=5 ICACHE_NUM_LINES=2"
)

for params in "${param_sets[@]}"; do
    make clean ARCH=pipeline PARAMS="$params"
    make ARCH=pipeline PARAMS="$params"
done

echo "All pipeline tests passed!"
