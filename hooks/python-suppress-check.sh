#!/bin/bash
# Python Suppress Comment Detection - PostToolUse hook
# Warns about noqa, type: ignore, and noinspection comments that bypass checks

set -e

file_path="${CLAUDE_FILE_PATH:-}"

if [[ -z "$file_path" ]] || [[ ! -f "$file_path" ]]; then
  exit 0
fi

# Only check Python files
if [[ ! "$file_path" =~ \.py$ ]]; then
  exit 0
fi

# Skip test files, migrations, venv
if [[ "$file_path" =~ (test_|_test\.py|conftest\.py|__pycache__|\.venv|migrations) ]]; then
  exit 0
fi

# Find suppress comments: noqa, type: ignore, noinspection
matches=$(grep -n -E "(#\s*noqa|#\s*type:\s*ignore|#\s*noinspection)" "$file_path" 2>/dev/null | head -10 || true)

if [[ -n "$matches" ]]; then
  count=$(echo "$matches" | wc -l | tr -d ' ')
  echo "🚫 [Suppress] Found $count suppression comment(s) in $(basename "$file_path"):" >&2
  echo "$matches" | while read -r line; do
    echo "   $line" >&2
  done
  echo "   💡 Fix the actual issue instead of suppressing lint/type errors" >&2
fi
