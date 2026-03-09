#!/bin/bash
# Python Type Check - PostToolUse hook for Edit/Write operations
# Runs mypy on edited Python files

set -e

file_path="${CLAUDE_FILE_PATH:-}"

# Skip if not a Python file
if [[ ! "$file_path" =~ \.py$ ]]; then
  exit 0
fi

# Skip test files, migrations
if [[ "$file_path" =~ (test_|_test\.py|conftest|__pycache__|\.venv|migrations) ]]; then
  exit 0
fi

# Find project root
dir=$(dirname "$file_path")
project_root=""
while [[ "$dir" != "/" ]]; do
  if [[ -f "$dir/pyproject.toml" ]]; then
    project_root="$dir"
    break
  fi
  dir=$(dirname "$dir")
done

if [[ -z "$project_root" ]]; then
  exit 0
fi

cd "$project_root"

# Check if mypy is available
if ! poetry run mypy --version &>/dev/null 2>&1; then
  exit 0
fi

# Run mypy on the specific file
errors=$(poetry run mypy "$file_path" --no-error-summary 2>/dev/null | grep -E "^${file_path}" 2>/dev/null | head -5 || true)

if [[ -n "$errors" ]]; then
  echo "⚠️  [mypy] Type errors in $(basename "$file_path"):" >&2
  echo "$errors" | while read -r line; do
    echo "   $line" >&2
  done
fi
