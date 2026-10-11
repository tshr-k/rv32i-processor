#!/usr/bin/env bash
set -euo pipefail

./scripts/run_unit_tests.sh
./scripts/run_single_cycle_tests.sh
./scripts/run_pipeline_tests.sh

echo "ALL TESTS PASSED!"
