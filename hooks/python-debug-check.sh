#!/bin/bash
# Python Debug Statement Detection - PostToolUse hook
# Warns about debug statements (print, breakpoint, pdb) in source code

set -e

file_path="${CLAUDE_FILE_PATH:-}"

if [[ -z "$file_path" ]] || [[ ! -f "$file_path" ]]; then
  exit 0
fi

# Only check Python files
if [[ ! "$file_path" =~ \.py$ ]]; then
  exit 0
fi

# Skip test files
if [[ "$file_path" =~ (test_|_test\.py|conftest\.py|__pycache__|\.venv) ]]; then
  exit 0
fi

# Find debug statements
matches=$(grep -n -E "(^[^#]*\bprint\(|breakpoint\(\)|import pdb|pdb\.set_trace\(\)|import ipdb|ipdb\.set_trace\(\))" "$file_path" 2>/dev/null | head -5 || true)

if [[ -n "$matches" ]]; then
  count=$(echo "$matches" | wc -l | tr -d ' ')
  echo "⚠️  [Debug] Found $count debug statement(s) in $(basename "$file_path"):" >&2
  echo "$matches" | while read -r line; do
    echo "   $line" >&2
  done
  echo "   💡 Remove print()/breakpoint() before commit" >&2
fi
