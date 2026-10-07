#!/usr/bin/env bash
set -euo pipefail

make -f Makefile.integration clean
make -f Makefile.integration

echo "All integration tests passed!"
