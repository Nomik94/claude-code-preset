#!/bin/bash
# 미완료 TODO 작업 계속 진행 — Stop hook
# 미완료 태스크가 남아있으면 Claude가 작업을 중단하지 않고 계속 진행하도록 강제한다.
# 무한루프 방지를 위해 최대 반복 횟수를 제한한다.

# 상태 저장 디렉토리
STATE_DIR="${HOME}/.claude/state"
ITERATION_FILE="${STATE_DIR}/iteration-count.json"
MAX_ITERATIONS=10

# 상태 디렉토리 생성
mkdir -p "$STATE_DIR" 2>/dev/null || true

# 현재 반복 횟수 읽기
read_iteration_count() {
  if [[ -f "$ITERATION_FILE" ]]; then
    # JSON에서 count 값 추출
    local count
    count=$(grep -o '"count"[[:space:]]*:[[:space:]]*[0-9]*' "$ITERATION_FILE" 2>/dev/null | grep -o '[0-9]*$' || echo "0")
    echo "${count:-0}"
  else
    echo "0"
  fi
}

# 반복 횟수 저장
write_iteration_count() {
  local count="$1"
  cat > "$ITERATION_FILE" 2>/dev/null << EOF
{
  "count": ${count},
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# 반복 횟수 초기화
reset_iteration_count() {
  write_iteration_count 0
}

# 미완료 태스크 수 집계
count_pending_tasks() {
  local pending=0

  # ~/.claude/todos/*.json에서 미완료 항목 확인
  if [[ -d "${HOME}/.claude/todos" ]]; then
    for todo_file in "${HOME}/.claude/todos/"*.json; do
      [[ -f "$todo_file" ]] || continue
      # status가 completed 또는 cancelled이 아닌 항목 카운트
      local file_pending
      file_pending=$(grep -c '"status"' "$todo_file" 2>/dev/null || echo "0")
      local file_done
      file_done=$(grep -cE '"status"[[:space:]]*:[[:space:]]*"(completed|cancelled)"' "$todo_file" 2>/dev/null || echo "0")
      pending=$((pending + file_pending - file_done))
    done
  fi

  # stdin에서 pending/in_progress 태스크 패턴 탐지
  # Stop hook은 stdin으로 데이터를 받을 수 있음
  if [[ ! -t 0 ]]; then
    local stdin_content
    stdin_content=$(cat 2>/dev/null) || true
    if [[ -n "$stdin_content" ]]; then
      local stdin_pending
      stdin_pending=$(echo "$stdin_content" | grep -cE '"status"[[:space:]]*:[[:space:]]*"(pending|in_progress)"' 2>/dev/null || echo "0")
      pending=$((pending + stdin_pending))
    fi
  fi

  # 음수 방지
  if [[ "$pending" -lt 0 ]]; then
    pending=0
  fi

  echo "$pending"
}

# 메인 로직
CURRENT_COUNT=$(read_iteration_count)
PENDING_TASKS=$(count_pending_tasks)

# 미완료 태스크가 있고 반복 제한 이내
if [[ "$PENDING_TASKS" -gt 0 ]] && [[ "$CURRENT_COUNT" -lt "$MAX_ITERATIONS" ]]; then
  # 반복 횟수 증가
  NEW_COUNT=$((CURRENT_COUNT + 1))
  write_iteration_count "$NEW_COUNT"

  echo "⚠️ 미완료 태스크 ${PENDING_TASKS}개 남아있습니다. 계속 진행합니다. (${NEW_COUNT}/${MAX_ITERATIONS})" >&2

  # exit 1 → Claude가 작업을 계속하도록 강제
  exit 1
fi

# 모든 태스크 완료 또는 MAX_ITERATIONS 초과
if [[ "$CURRENT_COUNT" -ge "$MAX_ITERATIONS" ]]; then
  echo "⚠️ 최대 반복 횟수(${MAX_ITERATIONS})에 도달했습니다. 작업을 종료합니다." >&2
fi

# 반복 횟수 초기화
reset_iteration_count

# exit 0 → 정상 종료 허용
exit 0
