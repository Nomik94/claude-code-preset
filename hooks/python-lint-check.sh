#!/bin/bash
# Python Lint & Format - PostToolUse hook for Edit/Write operations
# Auto-fixes with ruff, then reports remaining issues

set -e

file_path="${CLAUDE_FILE_PATH:-}"

# Skip if not a Python file
if [[ ! "$file_path" =~ \.py$ ]]; then
  exit 0
fi

# Skip __pycache__, .venv, migration versions
if [[ "$file_path" =~ (__pycache__|\.venv|migrations/versions) ]]; then
  exit 0
fi

# Find project root (look for pyproject.toml)
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

# Check if ruff is available via poetry
if ! poetry run ruff version &>/dev/null 2>&1; then
  exit 0
fi

# Snapshot before auto-fix
before_hash=$(md5 -q "$file_path" 2>/dev/null || md5sum "$file_path" 2>/dev/null | cut -d' ' -f1)

# Auto-fix: ruff check --fix + ruff format
poetry run ruff check --fix --quiet "$file_path" 2>/dev/null || true
poetry run ruff format --quiet "$file_path" 2>/dev/null || true

# Snapshot after auto-fix
after_hash=$(md5 -q "$file_path" 2>/dev/null || md5sum "$file_path" 2>/dev/null | cut -d' ' -f1)

# Report remaining issues (unfixable)
remaining=$(poetry run ruff check "$file_path" --no-fix 2>/dev/null | head -5 || true)

if [[ -n "$remaining" ]]; then
  count=$(echo "$remaining" | wc -l | tr -d ' ')
  echo "⚠️  [Ruff] $count unfixable issue(s) in $(basename "$file_path"):" >&2
  echo "$remaining" | while read -r line; do
    echo "   $line" >&2
  done
elif [[ "$before_hash" != "$after_hash" ]]; then
  echo "✨ [Ruff] Auto-formatted $(basename "$file_path")" >&2
fi
