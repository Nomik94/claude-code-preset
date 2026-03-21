#!/bin/bash
# TypeScript 타입 검사 — PostToolUse (Edit/Write)
# .ts/.tsx 파일 수정 시 tsc --noEmit으로 타입 에러를 검출한다.
# 수정된 파일에 해당하는 에러만 필터링하여 최대 5개 출력.

# 수정된 파일 경로
FILE_PATH="${CLAUDE_FILE_PATH:-}"

# 파일 경로가 없으면 종료
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# .ts 또는 .tsx 확장자만 처리
case "$FILE_PATH" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac

# 파일이 존재하는지 확인
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# tsconfig.json 탐색 (파일 디렉토리부터 상위로)
find_tsconfig() {
  local dir="$1"
  while [[ "$dir" != "/" && "$dir" != "" ]]; do
    if [[ -f "$dir/tsconfig.json" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

FILE_DIR=$(dirname "$FILE_PATH")
TSCONFIG_DIR=$(find_tsconfig "$FILE_DIR") || exit 0

# npx가 없으면 종료
if ! command -v npx &>/dev/null; then
  exit 0
fi

# tsc 실행 (에러가 나도 hook이 실패하면 안 됨)
TSC_OUTPUT=$(cd "$TSCONFIG_DIR" && npx tsc --noEmit --pretty false 2>&1) || true

# 수정된 파일에 해당하는 에러만 필터링
# tsc 출력 형식: "파일경로(행,열): error TS코드: 메시지"
# 절대 경로 또는 상대 경로 모두 매칭하기 위해 파일명 기반으로 필터링
FILE_BASENAME=$(basename "$FILE_PATH")
RELATIVE_PATH="${FILE_PATH#"$TSCONFIG_DIR"/}"

FILTERED=""
while IFS= read -r line; do
  # 수정된 파일 경로가 포함된 에러 줄만 추출
  if [[ "$line" == *"$RELATIVE_PATH"* ]] || [[ "$line" == *"$FILE_BASENAME"* ]]; then
    if [[ "$line" == *": error TS"* ]]; then
      FILTERED+="$line"$'\n'
    fi
  fi
done <<< "$TSC_OUTPUT"

# 에러가 없으면 아무것도 출력하지 않음
if [[ -z "$FILTERED" ]]; then
  exit 0
fi

# 최대 5개 에러 출력
ERROR_COUNT=0
echo "🔴 TypeScript 타입 에러:" >&2
while IFS= read -r line; do
  if [[ -z "$line" ]]; then
    continue
  fi
  echo "  $line" >&2
  ERROR_COUNT=$((ERROR_COUNT + 1))
  if [[ "$ERROR_COUNT" -ge 5 ]]; then
    # 남은 에러 수 계산
    TOTAL=$(echo "$FILTERED" | grep -c ": error TS" || true)
    REMAINING=$((TOTAL - 5))
    if [[ "$REMAINING" -gt 0 ]]; then
      echo "  ... 외 ${REMAINING}개 에러" >&2
    fi
    break
  fi
done <<< "$FILTERED"

exit 0
