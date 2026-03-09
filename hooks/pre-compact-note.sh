#!/bin/bash
# Pre-Compact Note Check - UserPromptSubmit hook
# Intercepts /compact command and reminds to save notes first

set -e

# Read stdin (JSON input from Claude Code)
INPUT=$(cat)

# Extract the prompt text
PROMPT=""
if command -v jq &> /dev/null; then
  PROMPT=$(echo "$INPUT" | jq -r '
    if .prompt then .prompt
    elif .message then .message
    elif .content then .content
    else ""
    end
  ' 2>/dev/null)
fi

# Fallback if jq fails
if [[ -z "$PROMPT" || "$PROMPT" == "null" ]]; then
  PROMPT=$(echo "$INPUT" | grep -oE '"(prompt|message|content)"\s*:\s*"[^"]+"' 2>/dev/null | head -1 | sed 's/.*: *"//;s/"$//' || true)
fi

if [[ -z "$PROMPT" ]]; then
  exit 0
fi

# Check for /compact command
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

if echo "$PROMPT_LOWER" | grep -qE '^\s*/compact\b'; then
  PROJECT_NOTEPAD="${PWD}/.claude/notepad.md"
  GLOBAL_NOTEPAD="${HOME}/.claude/notepad.md"

  NOTEPAD_FILE=""
  if [[ -f "$PROJECT_NOTEPAD" ]]; then
    NOTEPAD_FILE="$PROJECT_NOTEPAD"
  elif [[ -f "$GLOBAL_NOTEPAD" ]]; then
    NOTEPAD_FILE="$GLOBAL_NOTEPAD"
  fi

  WM_COUNT=0
  if [[ -n "$NOTEPAD_FILE" ]]; then
    WM_COUNT=$(grep -c '^\[' "$NOTEPAD_FILE" 2>/dev/null || true)
    WM_COUNT=${WM_COUNT:-0}
  fi

  echo "" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "📋 [Pre-Compact] Notepad: ${WM_COUNT} entries" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

  cat << EOF
{
  "continue": true,
  "message": "[PRE-COMPACT CHECK]\n\n압축 전 확인:\n✅ 현재 작업 진행상황 저장?\n✅ 핵심 파일 경로/라인 번호 메모?\n✅ 중요 발견사항 보존?\n\nNotepad entries: $WM_COUNT\nLocation: ${NOTEPAD_FILE:-none}\n\n누락 시 /note로 먼저 저장하세요."
}
EOF
fi

exit 0
