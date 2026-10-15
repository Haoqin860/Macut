#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h:h}"
cd "$TASK_ROOT"
export CLANG_MODULE_CACHE_PATH="$TASK_ROOT/.build/clang-module-cache"
export SWIFT_MODULECACHE_PATH="$TASK_ROOT/.build/swift-module-cache"
swift run --cache-path "$TASK_ROOT/.build/cache" CoreChecks
