---
name: build-fix
description: |
  빌드/린트 에러 자동 수정.
  Use when: ruff error, mypy error, TypeError, ImportError, SyntaxError,
  Build failed, 빌드 실패, 린트 에러, 타입 에러, ModuleNotFoundError.
  NOT for: 런타임 로직 버그, 비즈니스 로직 에러.
---

# Build Fix

빌드/린트 에러 감지 시 자동 실행.

## 자동 수정 흐름

1. **에러 분류**
   - Ruff lint error -> `poetry run ruff check --fix .`
   - Ruff format error -> `poetry run ruff format .`
   - mypy type error -> 수동 수정 (타입 힌트 추가/수정)
   - ImportError/ModuleNotFoundError -> `poetry add <package>`
   - SyntaxError -> 코드 수정

2. **수정 후 재검증**
   - 수정 적용 -> 해당 검증 재실행 -> 통과 확인

3. **실패 시**
   - 자동 수정 불가 -> 에러 원인 분석 -> 수정 제안

## 일반 수정 사항

| 에러 | 자동 수정 |
|------|----------|
| `F401` 미사용 import | `ruff check --fix` |
| `I001` import 순서 | `ruff check --fix` |
| `E501` 줄 길이 초과 | `ruff format` |
| mypy `missing return` | 반환 타입 추가 |
| mypy `incompatible type` | 타입 힌트 수정 |
| `ModuleNotFoundError` | `poetry add <pkg>` |

## 출력 형식
"Build Fix: [N errors fixed]" 또는 "Build Fix: [N errors remain] -- [manual fix needed]"
