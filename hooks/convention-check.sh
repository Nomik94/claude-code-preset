#!/bin/bash
# 네이밍 컨벤션 검사 — PostToolUse (Edit/Write)
# 언어별 네이밍 컨벤션 위반을 감지하여 권고한다.
# - Python: snake_case 함수/변수, PascalCase 클래스
# - JS/TS: camelCase 변수/함수, PascalCase 인터페이스/타입
# - CSS/SCSS: kebab-case 클래스
# - SQL: snake_case 테이블/컬럼
# 최대 5개 위반 출력.

# 수정된 파일 경로
FILE_PATH="${CLAUDE_FILE_PATH:-}"

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")
EXTENSION="${FILENAME##*.}"

# 스킵: 테스트/config/node_modules
case "$FILE_PATH" in
  */node_modules/*|*/__pycache__/*|*/.git/*)
    exit 0
    ;;
esac
case "$FILENAME" in
  test_*|*_test.py|*.test.*|*.spec.*|conftest.py)
    exit 0
    ;;
  *.config.*|setup.py|setup.cfg)
    exit 0
    ;;
esac

VIOLATIONS=""
VIOLATION_COUNT=0

# 위반 추가 헬퍼
add_violation() {
  if [[ "$VIOLATION_COUNT" -ge 5 ]]; then
    return
  fi
  VIOLATIONS+="  $1"$'\n'
  VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
}

# Python 컨벤션 검사
check_python() {
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [[ "$VIOLATION_COUNT" -ge 5 ]] && break

    # 주석/빈 줄 스킵
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ -z "$trimmed" ]] || [[ "$trimmed" == "#"* ]]; then
      continue
    fi

    # 함수 정의에서 camelCase 감지 (snake_case여야 함)
    # def myFunction( 또는 def getData( 패턴
    if [[ "$line" =~ ^[[:space:]]*def[[:space:]]+([a-z]+[A-Z][a-zA-Z]*)\( ]]; then
      local func_name="${BASH_REMATCH[1]}"
      # setUp/tearDown 같은 표준 메서드 제외
      case "$func_name" in
        setUp|tearDown|setUpClass|tearDownClass) continue ;;
      esac
      add_violation "L${line_num}: 함수 '${func_name}' → snake_case 권고 (예: $(echo "$func_name" | sed 's/\([A-Z]\)/_\L\1/g'))"
    fi

    # 클래스 정의에서 snake_case 감지 (PascalCase여야 함)
    # class my_class 또는 class some_thing 패턴
    if [[ "$line" =~ ^[[:space:]]*class[[:space:]]+([a-z][a-z0-9]*_[a-z_]+) ]]; then
      local class_name="${BASH_REMATCH[1]}"
      add_violation "L${line_num}: 클래스 '${class_name}' → PascalCase 권고"
    fi
  done < "$FILE_PATH"
}

# JavaScript/TypeScript 컨벤션 검사
check_javascript() {
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [[ "$VIOLATION_COUNT" -ge 5 ]] && break

    local trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ -z "$trimmed" ]] || [[ "$trimmed" == "//"* ]] || [[ "$trimmed" == "/*"* ]] || [[ "$trimmed" == "*"* ]]; then
      continue
    fi

    # 변수/함수에서 snake_case 감지 (camelCase여야 함)
    # const/let/var/function my_variable 패턴
    if [[ "$line" =~ (const|let|var|function)[[:space:]]+([a-z][a-z0-9]*_[a-z_]+) ]]; then
      local var_name="${BASH_REMATCH[2]}"
      # 일부 관용적 snake_case 제외 (예: __dirname, module_exports)
      case "$var_name" in
        __*|module_*) continue ;;
      esac
      add_violation "L${line_num}: 변수/함수 '${var_name}' → camelCase 권고"
    fi

    # interface/type에서 소문자 시작 감지 (PascalCase여야 함)
    if [[ "$line" =~ ^[[:space:]]*(interface|type)[[:space:]]+([a-z][a-zA-Z]*) ]]; then
      local type_name="${BASH_REMATCH[2]}"
      add_violation "L${line_num}: ${BASH_REMATCH[1]} '${type_name}' → PascalCase 권고"
    fi
  done < "$FILE_PATH"

  # React 컴포넌트 파일명 검사 (.tsx 파일이면서 소문자 시작)
  if [[ "$EXTENSION" == "tsx" ]]; then
    local base="${FILENAME%.*}"
    if [[ "$base" =~ ^[a-z] ]] && [[ "$base" != "index" ]] && [[ "$base" != *"."* ]]; then
      # 파일 내용에 JSX가 있는지 간단히 확인
      if grep -q "return.*<\|export.*function\|export.*const" "$FILE_PATH" 2>/dev/null; then
        add_violation "파일명 '${FILENAME}' → PascalCase 권고 (React 컴포넌트)"
      fi
    fi
  fi
}

# CSS/SCSS 컨벤션 검사
check_css() {
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [[ "$VIOLATION_COUNT" -ge 5 ]] && break

    # camelCase 클래스 감지 (kebab-case여야 함)
    # .myClassName 또는 .someClass 패턴
    if [[ "$line" =~ \.([a-z]+[A-Z][a-zA-Z]*)[[:space:]]*\{ ]] || \
       [[ "$line" =~ \.([a-z]+[A-Z][a-zA-Z]*)[[:space:]]*$ ]]; then
      local class_name="${BASH_REMATCH[1]}"
      add_violation "L${line_num}: 클래스 '.${class_name}' → kebab-case 권고"
    fi
  done < "$FILE_PATH"
}

# SQL 컨벤션 검사
check_sql() {
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [[ "$VIOLATION_COUNT" -ge 5 ]] && break

    # 주석 스킵
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ "$trimmed" == "--"* ]] || [[ -z "$trimmed" ]]; then
      continue
    fi

    # CREATE TABLE/ALTER TABLE에서 대문자 테이블명 감지
    if [[ "$line" =~ (CREATE[[:space:]]+TABLE|ALTER[[:space:]]+TABLE)[[:space:]]+[\"'\`]?([A-Z][A-Z_]*[A-Z])[\"'\`]? ]]; then
      local table_name="${BASH_REMATCH[2]}"
      add_violation "L${line_num}: 테이블 '${table_name}' → snake_case 권고"
    fi

    # 대문자 컬럼명 감지 (간단한 패턴)
    if [[ "$line" =~ [[:space:]]([A-Z][A-Z_]*[A-Z])[[:space:]]+(INT|VARCHAR|TEXT|BOOLEAN|TIMESTAMP|DATE|SERIAL|BIGINT|FLOAT|DECIMAL) ]]; then
      local col_name="${BASH_REMATCH[1]}"
      # SQL 키워드 제외
      case "$col_name" in
        NOT|NULL|DEFAULT|PRIMARY|FOREIGN|UNIQUE|CREATE|ALTER|TABLE|INDEX|CONSTRAINT) continue ;;
      esac
      add_violation "L${line_num}: 컬럼 '${col_name}' → snake_case 권고"
    fi
  done < "$FILE_PATH"
}

# 확장자별 분기
case "$EXTENSION" in
  py)
    check_python
    ;;
  js|jsx|ts|tsx)
    check_javascript
    ;;
  css|scss)
    check_css
    ;;
  sql)
    check_sql
    ;;
  *)
    exit 0
    ;;
esac

# 위반이 없으면 아무것도 출력하지 않음
if [[ -z "$VIOLATIONS" ]]; then
  exit 0
fi

echo "📋 네이밍 컨벤션 위반:" >&2
echo "$VIOLATIONS" >&2

exit 0
