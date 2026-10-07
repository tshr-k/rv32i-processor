#!/usr/bin/env bash
set -euo pipefail

./scripts/run_unit_tests.sh
./scripts/run_integration_tests.sh

echo "All tests passed!"