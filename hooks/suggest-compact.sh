#!/bin/bash
# Strategic Compact Suggestion - PreToolUse hook
# Counts tool calls and suggests /compact at strategic points
# BEFORE context limit is reached, preventing forced compaction
#
# Philosophy: Proactive compaction > Forced compaction
# - 50 tool calls → first suggestion
# - Every 25 after → reminder
# - User saves notes → runs /compact → clean context continues

set -e

# Configuration (override via env vars)
INITIAL_THRESHOLD=${COMPACT_INITIAL_THRESHOLD:-50}
REMINDER_INTERVAL=${COMPACT_REMINDER_INTERVAL:-25}
PROJECT_HASH=$(echo -n "$PWD" | md5 -q 2>/dev/null || echo -n "$PWD" | md5sum 2>/dev/null | cut -d' ' -f1)
COUNTER_FILE="/tmp/claude-tool-counter-${PROJECT_HASH}"
NOTEPAD_FILE="${PWD}/.claude/notepad.md"
GLOBAL_NOTEPAD="${HOME}/.claude/notepad.md"

# Use project notepad if exists, otherwise global
if [[ -f "$NOTEPAD_FILE" ]]; then
  ACTIVE_NOTEPAD="$NOTEPAD_FILE"
else
  ACTIVE_NOTEPAD="$GLOBAL_NOTEPAD"
fi

# Initialize counter
if [[ ! -f "$COUNTER_FILE" ]]; then
  echo "0" > "$COUNTER_FILE"
fi

# Read and increment
count=$(cat "$COUNTER_FILE")
count=$((count + 1))
echo "$count" > "$COUNTER_FILE"

# Check if we should suggest compaction
should_suggest=false
if [[ "$count" -eq "$INITIAL_THRESHOLD" ]]; then
  should_suggest=true
  suggestion_reason="도구 호출 ${INITIAL_THRESHOLD}회 도달"
elif [[ "$count" -gt "$INITIAL_THRESHOLD" ]]; then
  since_threshold=$((count - INITIAL_THRESHOLD))
  if [[ $((since_threshold % REMINDER_INTERVAL)) -eq 0 ]]; then
    should_suggest=true
    suggestion_reason="도구 호출 ${count}회 (컨텍스트 관리 필요)"
  fi
fi

if [[ "$should_suggest" == "true" ]]; then
  # Count existing notepad entries
  WM_COUNT=0
  if [[ -f "$ACTIVE_NOTEPAD" ]]; then
    WM_COUNT=$(grep -c '^\[' "$ACTIVE_NOTEPAD" 2>/dev/null || true)
    WM_COUNT=${WM_COUNT:-0}
  fi

  echo "" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "💭 [Context] $suggestion_reason" >&2
  echo "   Notepad entries: $WM_COUNT" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

  cat << 'EOF'
{
  "continue": true,
  "message": "[CONTEXT MANAGEMENT]\n\n컨텍스트 임계치 도달. /compact 실행 전 중요 정보를 저장하세요:\n\n1. `/note --priority <핵심 정보>` (항상 로드)\n2. `/note <작업 메모>` (Working Memory)\n3. 저장 후 `/compact` 실행\n\n저장 대상: 현재 작업 상태, 발견한 사항, 작업 중인 파일 경로\n\n⚠️ 압축 후 복구 불가능한 정보는 반드시 저장하세요."
}
EOF
fi
