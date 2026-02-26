---
name: verify
description: |
  구현 완료 후 품질 검증. 완료 선언 시 자동 실행.
  Use when: 완료, 끝, done, finished, PR, 커밋, 다 됐어, 마무리.
  NOT for: 중간 진행 상황 확인.
---

# 검증

구현 완료 후 자동 실행하는 6단계 검증.

## 검증 단계

### 1. Lint & Format
poetry run ruff check .
poetry run ruff format --check .

### 2. Type Check
poetry run mypy --strict app/

### 3. 아키텍처
poetry run lint-imports

### 4. 테스트
poetry run pytest --cov=app --cov-report=term-missing

### 5. 보안
poetry run ruff check --select S .

### 6. 의존성
poetry check && poetry lock --check

## 통과 기준
- 6단계 모두 통과 -> "검증 완료. 커밋 가능."
- 하나라도 실패 -> "검증 실패: [실패 항목]. 수정 필요."

## 출력 형식
"Verify: 6/6 passed" or "Verify: 4/6 passed -- [failing steps]"
