#!/usr/bin/env bash
# Freeze Mode: 허용 디렉토리 외 파일 수정 차단 스크립트
# PreToolUse hook으로 Edit/Write 실행 전 검사
# exit 0 = 허용, exit 2 = 차단

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SKILL_DIR/config.json"

# stdin에서 JSON 입력 읽기
INPUT=$(cat)

# Edit/Write 대상 파일 경로 추출
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# config.json 존재 여부 확인
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "BLOCKED [Freeze Mode]: config.json이 없습니다."
  echo "먼저 허용 디렉토리를 설정해주세요."
  echo "예시: config.json에 {\"allowed_dirs\": [\"src/auth/\", \"tests/auth/\"]} 형태로 저장"
  exit 2
fi

# 허용 디렉토리 목록 읽기
ALLOWED_DIRS=$(jq -r '.allowed_dirs[]? // empty' "$CONFIG_FILE" 2>/dev/null)

if [[ -z "$ALLOWED_DIRS" ]]; then
  echo "BLOCKED [Freeze Mode]: allowed_dirs가 비어있습니다."
  echo "config.json에 허용 디렉토리를 추가해주세요."
  exit 2
fi

# 파일 경로가 허용 디렉토리에 포함되는지 검사
while IFS= read -r allowed_dir; do
  # 상대 경로/절대 경로 모두 매칭
  if [[ "$FILE_PATH" == *"$allowed_dir"* ]]; then
    exit 0
  fi
done <<< "$ALLOWED_DIRS"

# 허용 디렉토리에 미포함 → 차단
echo "BLOCKED [Freeze Mode]: 허용 디렉토리 밖의 파일 수정이 차단되었습니다."
echo "대상 파일: $FILE_PATH"
echo "허용 디렉토리:"
echo "$ALLOWED_DIRS" | while IFS= read -r dir; do
  echo "  - $dir"
done
echo "수정이 필요하면 config.json의 allowed_dirs를 업데이트하세요."
exit 2
