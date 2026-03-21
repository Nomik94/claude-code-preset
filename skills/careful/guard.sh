#!/usr/bin/env bash
# Careful Mode: 위험 명령 차단 스크립트
# PreToolUse hook으로 Bash 명령 실행 전 검사
# exit 0 = 허용, exit 2 = 차단

set -euo pipefail

# stdin에서 JSON 입력 읽기
INPUT=$(cat)

# tool_input.command 추출
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# 차단 패턴 목록
BLOCKED_PATTERNS=(
  "rm -rf"
  "DROP TABLE"
  "DROP DATABASE"
  "git push --force"
  "git push -f"
  "kubectl delete"
  "docker system prune"
  "git reset --hard"
  "git clean -fd"
)

# 명령어를 대소문자 무시하고 검사
COMMAND_UPPER=$(echo "$COMMAND" | tr '[:lower:]' '[:upper:]')

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  PATTERN_UPPER=$(echo "$pattern" | tr '[:lower:]' '[:upper:]')
  if [[ "$COMMAND_UPPER" == *"$PATTERN_UPPER"* ]]; then
    echo "BLOCKED [Careful Mode]: 위험 명령 감지 - '$pattern'"
    echo "이 명령은 프로덕션 환경에서 치명적 결과를 초래할 수 있습니다."
    echo "실행이 차단되었습니다. 정말 필요하다면 사용자에게 명시적 확인을 요청하세요."
    exit 2
  fi
done

# 차단 패턴 없음 → 허용
exit 0
