#!/bin/bash
# 미완료 TODO 작업 계속 진행 — Stop hook
# Claude가 미완료 태스크가 있을 때 작업을 계속하도록 강제한다.
# stdin으로 전달되는 세션 데이터만 사용 (파일 시스템 탐색 제거)

MAX_ITERATIONS=5
STATE_DIR="${HOME}/.claude/state"
ITERATION_FILE="${STATE_DIR}/iteration-count.json"

mkdir -p "$STATE_DIR" 2>/dev/null || true

# 현재 반복 횟수 읽기
read_iteration_count() {
  if [[ -f "$ITERATION_FILE" ]]; then
    local count
    count=$(grep -o '"count"[[:space:]]*:[[:space:]]*[0-9]*' "$ITERATION_FILE" 2>/dev/null | grep -o '[0-9]*$' || echo "0")
    echo "${count:-0}"
  else
    echo "0"
  fi
}

write_iteration_count() {
  cat > "$ITERATION_FILE" 2>/dev/null << EOF
{
  "count": ${1},
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# stdin에서 미완료 태스크 감지 (유일한 소스)
PENDING=0
if [[ ! -t 0 ]]; then
  INPUT=$(cat 2>/dev/null) || true
  if [[ -n "$INPUT" ]]; then
    PENDING=$(echo "$INPUT" | grep -cE '"status"[[:space:]]*:[[:space:]]*"(pending|in_progress)"' 2>/dev/null || echo "0")
  fi
fi

CURRENT_COUNT=$(read_iteration_count)

if [[ "$PENDING" -gt 0 ]] && [[ "$CURRENT_COUNT" -lt "$MAX_ITERATIONS" ]]; then
  NEW_COUNT=$((CURRENT_COUNT + 1))
  write_iteration_count "$NEW_COUNT"
  echo "⚠️ 미완료 태스크 ${PENDING}개. 계속 진행합니다. (${NEW_COUNT}/${MAX_ITERATIONS})" >&2
  exit 1
fi

if [[ "$CURRENT_COUNT" -ge "$MAX_ITERATIONS" ]]; then
  echo "⚠️ 최대 반복 횟수(${MAX_ITERATIONS})에 도달. 작업을 종료합니다." >&2
fi

write_iteration_count 0
exit 0
