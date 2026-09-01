#!/usr/bin/env bash
# Runs every tests/test-*.sh against the repository root.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
. tests/lib/harness.sh

for t in tests/test-*.sh; do
    printf '\n%s\n' "$t"
    . "$t"
done

summary
