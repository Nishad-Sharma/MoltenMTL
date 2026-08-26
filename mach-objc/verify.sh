#!/usr/bin/env bash
set -euo pipefail

./generate.sh
diff_output=$(git diff)

if [ -n "$diff_output" ]; then
    echo "$diff_output"
    exit 1
else
    echo "(no diff compared to upstream)"
fi
