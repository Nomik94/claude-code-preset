#!/bin/bash
# 디버그 코드 + 억제 주석 감지 — PostToolUse (Edit/Write)
# 1) print(), console.log() 등 디버그용 코드 감지
# 2) noqa, type: ignore, @ts-ignore, eslint-disable 등 억제 주석 감지
# 테스트/config 파일은 스킵. 최대 3개씩 출력.

# 수정된 파일 경로
FILE_PATH="${CLAUDE_FILE_PATH:-}"

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")

# 스킵: node_modules, __pycache__
case "$FILE_PATH" in
  */node_modules/*|*/__pycache__/*)
    exit 0
    ;;
esac

# 스킵: 테스트 파일
case "$FILENAME" in
  test_*|*_test.py|*.test.*|*.spec.*|conftest.py)
    exit 0
    ;;
esac

# 스킵: config 파일
case "$FILENAME" in
  *.config.*|setup.py|setup.cfg)
    exit 0
    ;;
esac

EXTENSION="${FILENAME##*.}"
MATCHES=""

# Python 파일: print(), breakpoint(), pdb 감지
detect_python() {
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    # noqa 주석이 있는 줄은 제외
    if [[ "$line" == *"noqa"* ]]; then
      continue
    fi
    # 주석 줄 제외 (앞 공백 무시)
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ "$trimmed" == "#"* ]]; then
      continue
    fi
    # 디버그 패턴 감지
    if [[ "$line" =~ print\( ]] || \
       [[ "$line" =~ breakpoint\(\) ]] || \
       [[ "$line" =~ pdb\.set_trace\(\) ]] || \
       [[ "$line" =~ import\ pdb ]]; then
      MATCHES+="  L${line_num}: ${line}"$'\n'
    fi
  done < "$FILE_PATH"
}

# JS/TS 파일: console.* 감지
detect_javascript() {
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    # eslint-disable 주석이 있는 줄은 제외
    if [[ "$line" == *"eslint-disable"* ]]; then
      continue
    fi
    # 주석 줄 제외
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ "$trimmed" == "//"* ]]; then
      continue
    fi
    # 디버그 패턴 감지
    if [[ "$line" =~ console\.log\( ]] || \
       [[ "$line" =~ console\.debug\( ]] || \
       [[ "$line" =~ console\.info\( ]] || \
       [[ "$line" =~ console\.warn\( ]] || \
       [[ "$line" =~ console\.error\( ]]; then
      MATCHES+="  L${line_num}: ${line}"$'\n'
    fi
  done < "$FILE_PATH"
}

# 확장자별 분기
case "$EXTENSION" in
  py)
    detect_python
    ;;
  js|jsx|ts|tsx)
    detect_javascript
    ;;
  *)
    exit 0
    ;;
esac

# === 억제 주석 감지 ===
SUPPRESS_MATCHES=""

detect_suppress() {
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    # 주석 줄 자체는 제외 (인라인 억제만 감지)
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ "$trimmed" == "#"* ]] || [[ "$trimmed" == "//"* ]]; then
      continue
    fi
    # Python 억제: noqa, type: ignore
    if [[ "$line" =~ noqa ]] || [[ "$line" =~ type:\ *ignore ]]; then
      SUPPRESS_MATCHES+="  L${line_num}: ${line}"$'\n'
    fi
    # TypeScript/JS 억제: @ts-ignore, @ts-nocheck, @ts-expect-error, eslint-disable
    if [[ "$line" =~ @ts-ignore ]] || \
       [[ "$line" =~ @ts-nocheck ]] || \
       [[ "$line" =~ @ts-expect-error ]] || \
       [[ "$line" =~ eslint-disable ]]; then
      SUPPRESS_MATCHES+="  L${line_num}: ${line}"$'\n'
    fi
  done < "$FILE_PATH"
}

case "$EXTENSION" in
  py|js|jsx|ts|tsx)
    detect_suppress
    ;;
esac

# === 출력 ===

output_matches() {
  local label="$1"
  local data="$2"
  local max="$3"
  if [[ -z "$data" ]]; then
    return
  fi
  echo "$label" >&2
  local count=0
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then continue; fi
    echo "$line" >&2
    count=$((count + 1))
    if [[ "$count" -ge "$max" ]]; then break; fi
  done <<< "$data"
}

if [[ -z "$MATCHES" ]] && [[ -z "$SUPPRESS_MATCHES" ]]; then
  exit 0
fi

output_matches "⚠️ 디버그 코드 감지:" "$MATCHES" 3
output_matches "⚠️ 억제 주석 감지 (정당한 사유 없이 사용 금지):" "$SUPPRESS_MATCHES" 3

if [[ -n "$MATCHES" ]]; then
  echo "⚠️ 커밋 전 디버그 코드를 제거하세요" >&2
fi

exit 0
