#!/bin/bash
# 공통 유틸리티 함수 — PostToolUse 훅에서 사용
# 파일 경로 유효성, 스킵 판단, 상위 탐색, 주석 판단 등

# 스킵 대상 디렉토리 목록
SKIP_DIRS="node_modules|__pycache__|\.git|\.next|dist|build|\.venv|venv"

# 파일 경로 유효성 검사 (빈 값, 존재 여부)
# 사용: validate_file_path "$path" || exit 0
validate_file_path() {
  local path="$1"
  [[ -n "$path" ]] && [[ -f "$path" ]]
}

# 스킵 디렉토리 판단
# 사용: should_skip_dir "$path" && exit 0
should_skip_dir() {
  local path="$1"
  [[ "$path" =~ /($SKIP_DIRS)/ ]]
}

# 테스트/config 파일 스킵 판단
# 사용: should_skip_test "$filename" && exit 0
should_skip_test() {
  local filename="$1"
  case "$filename" in
    test_*|*_test.py|*.test.*|*.spec.*|conftest.py)
      return 0 ;;
    *.config.*|setup.py|setup.cfg)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# 상위 디렉토리 탐색 — 지정 파일이 있는 디렉토리 반환
# 사용: dir=$(find_up "$start_dir" "tsconfig.json") || exit 0
find_up() {
  local dir="$1"
  local target="$2"
  while [[ "$dir" != "/" && "$dir" != "" ]]; do
    if [[ -f "$dir/$target" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

# 주석 줄 판단 (Python #, JS //, CSS /*, SQL --)
# 사용: is_comment_line "$trimmed_line" "$ext" && continue
is_comment_line() {
  local trimmed="$1"
  local ext="$2"
  case "$ext" in
    py)
      [[ "$trimmed" == "#"* ]] ;;
    js|jsx|ts|tsx)
      [[ "$trimmed" == "//"* ]] || [[ "$trimmed" == "/*"* ]] || [[ "$trimmed" == "*"* ]] ;;
    css|scss)
      [[ "$trimmed" == "/*"* ]] || [[ "$trimmed" == "*"* ]] ;;
    sql)
      [[ "$trimmed" == "--"* ]] ;;
    *)
      return 1 ;;
  esac
}

# 선행 공백 제거 유틸
trim_leading() {
  local line="$1"
  echo "${line#"${line%%[![:space:]]*}"}"
}

# 결과 출력 헬퍼 (최대 N개, stderr로)
# 사용: output_matches "라벨" "$data" 3
output_matches() {
  local label="$1"
  local data="$2"
  local max="$3"
  if [[ -z "$data" ]]; then
    return 1
  fi
  echo "$label" >&2
  local count=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" >&2
    count=$((count + 1))
    [[ "$count" -ge "$max" ]] && break
  done <<< "$data"
  return 0
}

# 프로젝트 로컬 바이너리 경로 해석 (npx fallback)
# 사용: BIN=$(resolve_bin "prettier" "$file_path")
resolve_bin() {
  local cmd="$1"
  local file_path="$2"
  # 파일 기준 상위에서 node_modules/.bin 탐색
  local dir
  dir=$(dirname "$file_path")
  while [[ "$dir" != "/" && "$dir" != "" ]]; do
    if [[ -x "$dir/node_modules/.bin/$cmd" ]]; then
      echo "$dir/node_modules/.bin/$cmd"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  # fallback: npx
  if command -v npx &>/dev/null; then
    echo "npx $cmd"
    return 0
  fi
  return 1
}
