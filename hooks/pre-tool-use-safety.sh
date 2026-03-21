#!/bin/bash
# PreToolUse 안전 hook — 위험 명령 사전 차단
# exit 0: 허용, exit 2: 차단 (stderr 메시지가 Claude에게 전달됨)

INPUT=$(cat 2>/dev/null) || true
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[[ -z "$COMMAND" ]] && exit 0

# 위험 패턴 목록 (패턴|설명)
BLOCKED=(
  'rm -rf /$|루트 삭제'
  'rm -rf /\s|루트 삭제'
  'rm -rf ~/?$|홈 디렉토리 삭제'
  'rm -rf ~/ |홈 디렉토리 삭제'
  'rm -rf \.\/?$|현재 디렉토리 전체 삭제'
  'rm -rf \.\/ |현재 디렉토리 전체 삭제'
  'git push.*--force|force push'
  'git push.*-f[^i]|force push (-f)'
  'git reset --hard|hard reset'
  'git clean -fd|추적되지 않는 파일 전체 삭제'
  'DROP DATABASE|데이터베이스 삭제'
  'DROP TABLE|테이블 삭제'
  'TRUNCATE |테이블 데이터 전체 삭제'
  'mkfs\.|파일시스템 포맷'
  'dd if=|디스크 직접 쓰기'
  '> /dev/sd|디스크 직접 쓰기'
  'chmod -R 777|전체 권한 개방'
  'curl.*\| *sh|원격 스크립트 파이프 실행'
  'wget.*\| *sh|원격 스크립트 파이프 실행'
)

for entry in "${BLOCKED[@]}"; do
  pattern="${entry%%|*}"
  description="${entry##*|}"
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "🚫 위험 명령 차단: ${description}" >&2
    echo "명령: ${COMMAND}" >&2
    echo "이 명령을 실행하려면 사용자에게 명시적 확인을 받으세요." >&2
    exit 2
  fi
done

exit 0
