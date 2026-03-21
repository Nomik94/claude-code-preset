#!/bin/bash
# 통합 PostToolUse dispatcher — Edit/Write 후 확장자 기반 검사 실행
# 포함 기능: auto-format, type-check, console-log-check, convention-check

source "$(dirname "$0")/common.sh"

FILE_PATH="${CLAUDE_FILE_PATH:-}"
validate_file_path "$FILE_PATH" || exit 0
should_skip_dir "$FILE_PATH" && exit 0

FILENAME=$(basename "$FILE_PATH")
EXT="${FILENAME##*.}"

# ============================================================
# 포맷팅 함수
# ============================================================

# Python 포맷 (ruff format + ruff check --fix)
run_format_python() {
  local file="$1"
  command -v ruff &>/dev/null || return
  local hash_before hash_after
  hash_before=$(md5 -q "$file" 2>/dev/null || md5sum "$file" 2>/dev/null | cut -d' ' -f1) || return
  ruff format "$file" 2>/dev/null || true
  ruff check --fix "$file" 2>/dev/null || true
  hash_after=$(md5 -q "$file" 2>/dev/null || md5sum "$file" 2>/dev/null | cut -d' ' -f1) || return
  if [[ "$hash_before" != "$hash_after" ]]; then
    echo "Auto-formatted: ${file##*/}" >&2
  fi
}

# Web 포맷 (Prettier)
run_format_web() {
  local file="$1"
  # prettier 설정 또는 의존성 확인
  local has_prettier=false
  local dir
  dir=$(dirname "$file")
  while [[ "$dir" != "/" && "$dir" != "" ]]; do
    for rc in ".prettierrc" ".prettierrc.js" ".prettierrc.cjs" ".prettierrc.mjs" \
              ".prettierrc.json" ".prettierrc.yml" ".prettierrc.yaml" \
              ".prettierrc.toml" "prettier.config.js" "prettier.config.cjs" \
              "prettier.config.mjs"; do
      if [[ -f "$dir/$rc" ]]; then
        has_prettier=true
        break 2
      fi
    done
    if [[ -f "$dir/package.json" ]] && grep -q '"prettier"' "$dir/package.json" 2>/dev/null; then
      has_prettier=true
      break
    fi
    dir=$(dirname "$dir")
  done
  [[ "$has_prettier" == "true" ]] || return

  local prettier_bin
  prettier_bin=$(resolve_bin "prettier" "$file") || return
  local hash_before hash_after
  hash_before=$(md5 -q "$file" 2>/dev/null || md5sum "$file" 2>/dev/null | cut -d' ' -f1) || return
  # resolve_bin이 "npx prettier"를 반환할 수 있으므로 eval 사용
  $prettier_bin --write "$file" 2>/dev/null || true
  hash_after=$(md5 -q "$file" 2>/dev/null || md5sum "$file" 2>/dev/null | cut -d' ' -f1) || return
  if [[ "$hash_before" != "$hash_after" ]]; then
    echo "Auto-formatted: ${file##*/}" >&2
  fi
}

# ============================================================
# 타입 검사 함수 (ts/tsx 전용, 10초 throttle)
# ============================================================

run_type_check() {
  local file="$1"
  # throttle: 마지막 실행 후 10초 이내면 건너뜀
  local stamp_file="/tmp/.claude-tsc-last-run"
  local now
  now=$(date +%s)
  if [[ -f "$stamp_file" ]]; then
    local last_run
    last_run=$(cat "$stamp_file" 2>/dev/null)
    if [[ -n "$last_run" ]] && (( now - last_run < 10 )); then
      return
    fi
  fi
  echo "$now" > "$stamp_file" 2>/dev/null

  local file_dir tsconfig_dir
  file_dir=$(dirname "$file")
  tsconfig_dir=$(find_up "$file_dir" "tsconfig.json") || return

  local tsc_bin
  tsc_bin=$(resolve_bin "tsc" "$file") || return

  local tsc_output
  tsc_output=$(cd "$tsconfig_dir" && $tsc_bin --noEmit --pretty false 2>&1) || true

  # 수정된 파일에 해당하는 에러만 필터링
  local relative_path="${file#"$tsconfig_dir"/}"
  local filtered=""
  while IFS= read -r line; do
    if [[ "$line" == *": error TS"* ]]; then
      if [[ "$line" == *"$relative_path"* ]] || [[ "$line" == *"$file"* ]]; then
        filtered+="$line"$'\n'
      fi
    fi
  done <<< "$tsc_output"

  [[ -z "$filtered" ]] && return

  # 최대 5개 에러 출력
  local error_count=0
  echo "TypeScript 타입 에러:" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "  $line" >&2
    error_count=$((error_count + 1))
    if [[ "$error_count" -ge 5 ]]; then
      local total remaining
      total=$(echo "$filtered" | grep -c ": error TS" || true)
      remaining=$((total - 5))
      if [[ "$remaining" -gt 0 ]]; then
        echo "  ... 외 ${remaining}개 에러" >&2
      fi
      break
    fi
  done <<< "$filtered"
}

# ============================================================
# 디버그 코드 + 억제 주석 감지 (1회 순회 통합)
# ============================================================

run_debug_check_python() {
  local file="$1"
  should_skip_test "$(basename "$file")" && return
  local debug_matches="" suppress_matches=""
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    local trimmed
    trimmed=$(trim_leading "$line")
    # 빈 줄/주석 스킵
    [[ -z "$trimmed" ]] && continue
    [[ "$trimmed" == "#"* ]] && continue

    # 디버그 패턴 (noqa가 있는 줄은 디버그 감지 제외)
    if [[ "$line" != *"noqa"* ]]; then
      if [[ "$line" =~ print\( ]] || \
         [[ "$line" =~ breakpoint\(\) ]] || \
         [[ "$line" =~ pdb\.set_trace\(\) ]] || \
         [[ "$line" =~ import\ pdb ]]; then
        debug_matches+="  L${line_num}: ${line}"$'\n'
      fi
    fi

    # 억제 주석 (인라인만 — 주석 줄 자체는 위에서 제외됨)
    if [[ "$line" =~ noqa ]] || [[ "$line" =~ type:\ *ignore ]]; then
      suppress_matches+="  L${line_num}: ${line}"$'\n'
    fi
  done < "$file"

  [[ -z "$debug_matches" ]] && [[ -z "$suppress_matches" ]] && return
  output_matches "디버그 코드 감지:" "$debug_matches" 3 || true
  output_matches "억제 주석 감지 (정당한 사유 없이 사용 금지):" "$suppress_matches" 3 || true
  if [[ -n "$debug_matches" ]]; then
    echo "커밋 전 디버그 코드를 제거하세요" >&2
  fi
}

run_debug_check_js() {
  local file="$1"
  should_skip_test "$(basename "$file")" && return
  local debug_matches="" suppress_matches=""
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    local trimmed
    trimmed=$(trim_leading "$line")
    [[ -z "$trimmed" ]] && continue
    [[ "$trimmed" == "//"* ]] && continue

    # 디버그 패턴 (eslint-disable이 있는 줄은 디버그 감지 제외)
    if [[ "$line" != *"eslint-disable"* ]]; then
      if [[ "$line" =~ console\.log\( ]] || \
         [[ "$line" =~ console\.debug\( ]] || \
         [[ "$line" =~ console\.info\( ]] || \
         [[ "$line" =~ console\.warn\( ]] || \
         [[ "$line" =~ console\.error\( ]]; then
        debug_matches+="  L${line_num}: ${line}"$'\n'
      fi
    fi

    # 억제 주석 (인라인만)
    if [[ "$line" =~ @ts-ignore ]] || \
       [[ "$line" =~ @ts-nocheck ]] || \
       [[ "$line" =~ @ts-expect-error ]] || \
       [[ "$line" =~ eslint-disable ]]; then
      suppress_matches+="  L${line_num}: ${line}"$'\n'
    fi
  done < "$file"

  [[ -z "$debug_matches" ]] && [[ -z "$suppress_matches" ]] && return
  output_matches "디버그 코드 감지:" "$debug_matches" 3 || true
  output_matches "억제 주석 감지 (정당한 사유 없이 사용 금지):" "$suppress_matches" 3 || true
  if [[ -n "$debug_matches" ]]; then
    echo "커밋 전 디버그 코드를 제거하세요" >&2
  fi
}

# ============================================================
# 네이밍 컨벤션 검사
# ============================================================

run_convention_python() {
  local file="$1"
  should_skip_test "$(basename "$file")" && return
  local violations="" vcount=0
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [[ "$vcount" -ge 5 ]] && break
    local trimmed
    trimmed=$(trim_leading "$line")
    [[ -z "$trimmed" ]] && continue
    [[ "$trimmed" == "#"* ]] && continue

    # 함수: camelCase → snake_case 권고
    if [[ "$line" =~ ^[[:space:]]*def[[:space:]]+([a-z]+[A-Z][a-zA-Z]*)\( ]]; then
      local func_name="${BASH_REMATCH[1]}"
      case "$func_name" in
        setUp|tearDown|setUpClass|tearDownClass) continue ;;
      esac
      violations+="  L${line_num}: 함수 '${func_name}' → snake_case 권고 (예: $(echo "$func_name" | sed 's/\([A-Z]\)/_\L\1/g'))"$'\n'
      vcount=$((vcount + 1))
    fi

    # 클래스: snake_case → PascalCase 권고
    if [[ "$line" =~ ^[[:space:]]*class[[:space:]]+([a-z][a-z0-9]*_[a-z_]+) ]]; then
      local class_name="${BASH_REMATCH[1]}"
      violations+="  L${line_num}: 클래스 '${class_name}' → PascalCase 권고"$'\n'
      vcount=$((vcount + 1))
    fi
  done < "$file"

  output_matches "네이밍 컨벤션 위반:" "$violations" 5 || true
}

run_convention_js() {
  local file="$1"
  local ext="${file##*.}"
  should_skip_test "$(basename "$file")" && return
  local violations="" vcount=0
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [[ "$vcount" -ge 5 ]] && break
    local trimmed
    trimmed=$(trim_leading "$line")
    [[ -z "$trimmed" ]] && continue
    is_comment_line "$trimmed" "$ext" && continue

    # 변수/함수: snake_case → camelCase 권고
    if [[ "$line" =~ (const|let|var|function)[[:space:]]+([a-z][a-z0-9]*_[a-z_]+) ]]; then
      local var_name="${BASH_REMATCH[2]}"
      case "$var_name" in
        __*|module_*) continue ;;
      esac
      violations+="  L${line_num}: 변수/함수 '${var_name}' → camelCase 권고"$'\n'
      vcount=$((vcount + 1))
    fi

    # interface/type: 소문자 시작 → PascalCase 권고
    if [[ "$line" =~ ^[[:space:]]*(interface|type)[[:space:]]+([a-z][a-zA-Z]*) ]]; then
      local type_name="${BASH_REMATCH[2]}"
      violations+="  L${line_num}: ${BASH_REMATCH[1]} '${type_name}' → PascalCase 권고"$'\n'
      vcount=$((vcount + 1))
    fi
  done < "$file"

  # React 컴포넌트 파일명 검사 (.tsx)
  if [[ "$ext" == "tsx" ]] && [[ "$vcount" -lt 5 ]]; then
    local base="${FILENAME%.*}"
    if [[ "$base" =~ ^[a-z] ]] && [[ "$base" != "index" ]] && [[ "$base" != *"."* ]]; then
      if grep -q "return.*<\|export.*function\|export.*const" "$file" 2>/dev/null; then
        violations+="  파일명 '$(basename "$file")' → PascalCase 권고 (React 컴포넌트)"$'\n'
        vcount=$((vcount + 1))
      fi
    fi
  fi

  output_matches "네이밍 컨벤션 위반:" "$violations" 5 || true
}

run_convention_css() {
  local file="$1"
  local violations="" vcount=0
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [[ "$vcount" -ge 5 ]] && break
    # camelCase 클래스 → kebab-case 권고
    if [[ "$line" =~ \.([a-z]+[A-Z][a-zA-Z]*)[[:space:]]*\{ ]] || \
       [[ "$line" =~ \.([a-z]+[A-Z][a-zA-Z]*)[[:space:]]*$ ]]; then
      local class_name="${BASH_REMATCH[1]}"
      violations+="  L${line_num}: 클래스 '.${class_name}' → kebab-case 권고"$'\n'
      vcount=$((vcount + 1))
    fi
  done < "$file"

  output_matches "네이밍 컨벤션 위반:" "$violations" 5 || true
}

run_convention_sql() {
  local file="$1"
  local violations="" vcount=0
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [[ "$vcount" -ge 5 ]] && break
    local trimmed
    trimmed=$(trim_leading "$line")
    [[ "$trimmed" == "--"* ]] && continue
    [[ -z "$trimmed" ]] && continue

    # 대문자 테이블명 감지
    if [[ "$line" =~ (CREATE[[:space:]]+TABLE|ALTER[[:space:]]+TABLE)[[:space:]]+[\"\'\`]?([A-Z][A-Z_]*[A-Z])[\"\'\`]? ]]; then
      local table_name="${BASH_REMATCH[2]}"
      violations+="  L${line_num}: 테이블 '${table_name}' → snake_case 권고"$'\n'
      vcount=$((vcount + 1))
    fi

    # 대문자 컬럼명 감지
    if [[ "$line" =~ [[:space:]]([A-Z][A-Z_]*[A-Z])[[:space:]]+(INT|VARCHAR|TEXT|BOOLEAN|TIMESTAMP|DATE|SERIAL|BIGINT|FLOAT|DECIMAL) ]]; then
      local col_name="${BASH_REMATCH[1]}"
      case "$col_name" in
        NOT|NULL|DEFAULT|PRIMARY|FOREIGN|UNIQUE|CREATE|ALTER|TABLE|INDEX|CONSTRAINT) continue ;;
      esac
      violations+="  L${line_num}: 컬럼 '${col_name}' → snake_case 권고"$'\n'
      vcount=$((vcount + 1))
    fi
  done < "$file"

  output_matches "네이밍 컨벤션 위반:" "$violations" 5 || true
}

# ============================================================
# Dispatcher — 확장자 기반 분기
# ============================================================

case "$EXT" in
  py)
    run_format_python "$FILE_PATH"
    run_convention_python "$FILE_PATH"
    run_debug_check_python "$FILE_PATH"
    ;;
  ts|tsx)
    run_format_web "$FILE_PATH"
    run_convention_js "$FILE_PATH"
    run_debug_check_js "$FILE_PATH"
    run_type_check "$FILE_PATH"
    ;;
  js|jsx)
    run_format_web "$FILE_PATH"
    run_convention_js "$FILE_PATH"
    run_debug_check_js "$FILE_PATH"
    ;;
  css|scss)
    run_format_web "$FILE_PATH"
    run_convention_css "$FILE_PATH"
    ;;
  sql)
    run_convention_sql "$FILE_PATH"
    ;;
  json|md|yaml|yml|html)
    run_format_web "$FILE_PATH"
    ;;
  *)
    exit 0
    ;;
esac

exit 0
