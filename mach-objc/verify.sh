#!/usr/bin/env bash
set -euo pipefail

zig build generate
zig build test

repo_root=$(git rev-parse --show-toplevel)
git -C "$repo_root" diff --exit-code -- mach-objc
