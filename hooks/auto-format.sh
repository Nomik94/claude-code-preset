#!/bin/bash
# 자동 포맷팅 — PostToolUse (Edit/Write)
# 파일 확장자에 따라 적절한 포맷터를 실행한다.
# - Python: ruff format + ruff check --fix
# - Web: Prettier (prettier 의존성 또는 설정 파일 존재 시)
# 포맷 변경이 있을 때만 메시지를 출력한다.

# 수정된 파일 경로
FILE_PATH="${CLAUDE_FILE_PATH:-}"

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# 스킵할 디렉토리 패턴
case "$FILE_PATH" in
  */node_modules/*|*/.next/*|*/dist/*|*/build/*|*/.git/*)
    exit 0
    ;;
esac

FILENAME=$(basename "$FILE_PATH")
EXTENSION="${FILENAME##*.}"

# 포맷 전 파일 내용 저장 (변경 감지용)
BEFORE=$(cat "$FILE_PATH" 2>/dev/null) || exit 0

# Python 파일 처리
format_python() {
  if ! command -v ruff &>/dev/null; then
    return
  fi
  ruff format "$FILE_PATH" 2>/dev/null || true
  ruff check --fix "$FILE_PATH" 2>/dev/null || true
}

# Prettier 사용 가능 여부 확인
has_prettier() {
  # .prettierrc* 파일 존재 확인 (프로젝트 루트 탐색)
  local dir
  dir=$(dirname "$FILE_PATH")
  while [[ "$dir" != "/" && "$dir" != "" ]]; do
    # prettier 설정 파일 확인
    for rc in ".prettierrc" ".prettierrc.js" ".prettierrc.cjs" ".prettierrc.mjs" \
              ".prettierrc.json" ".prettierrc.yml" ".prettierrc.yaml" \
              ".prettierrc.toml" "prettier.config.js" "prettier.config.cjs" \
              "prettier.config.mjs"; do
      if [[ -f "$dir/$rc" ]]; then
        return 0
      fi
    done
    # package.json에 prettier 의존성 확인
    if [[ -f "$dir/package.json" ]]; then
      if grep -q '"prettier"' "$dir/package.json" 2>/dev/null; then
        return 0
      fi
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

# Prettier로 포맷
format_prettier() {
  if ! has_prettier; then
    return
  fi
  if ! command -v npx &>/dev/null; then
    return
  fi
  npx prettier --write "$FILE_PATH" 2>/dev/null || true
}

# 확장자별 분기
case "$EXTENSION" in
  py)
    format_python
    ;;
  ts|tsx|js|jsx|json|css|scss|md|yaml|yml|html)
    format_prettier
    ;;
  *)
    exit 0
    ;;
esac

# 포맷 전후 비교
AFTER=$(cat "$FILE_PATH" 2>/dev/null) || exit 0

if [[ "$BEFORE" != "$AFTER" ]]; then
  echo "✨ Auto-formatted: ${FILENAME}" >&2
fi

exit 0
