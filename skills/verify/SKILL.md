---
name: verify
description: |
  구현 완료 후 7단계 품질 검증. 완료 선언 시 자동 실행.
  Use when: 완료, 끝, done, finished, PR, 커밋, 다 됐어, 마무리.
  NOT for: 중간 진행 상황 확인.
---

# 검증

구현 완료 후 자동 실행하는 7단계 검증.

## Stack Detection

프로젝트 파일로 검증 도구 자동 결정:
- `pyproject.toml` → BE 도구 사용
- `package.json` → FE 도구 사용
- 둘 다 → 양쪽 모두 실행

## 검증 단계

### 1. Lint & Format

| Stack | 명령어 |
|-------|--------|
| BE | `poetry run ruff check .` / `poetry run ruff format --check .` |
| FE | `pnpm eslint .` / `pnpm prettier --check .` |

### 2. Type Check

| Stack | 명령어 |
|-------|--------|
| BE | `poetry run mypy --strict app/` |
| FE | `pnpm tsc --noEmit` |

### 3. Architecture

| Stack | 검사 항목 |
|-------|----------|
| BE | 레이어 위반 (controller → repository 직접 호출), 순환 import, domain/에 framework import |
| FE | Server/Client Component 분리, barrel export 순환, 상태관리 레이어 위반 |
| 공통 | 순환 의존성 검사 |

### 4. Test

| Stack | 명령어 |
|-------|--------|
| BE | `poetry run pytest --cov=app --cov-report=term-missing --cov-fail-under=80` |
| FE | `pnpm test --coverage` (jest 또는 vitest) |

### 5. Security

| Stack | 검사 항목 |
|-------|----------|
| BE | 하드코딩 시크릿, SQL injection (raw query), `S` 규칙 (`ruff check --select S`) |
| FE | XSS (dangerouslySetInnerHTML), 하드코딩 API 키, 민감 데이터 클라이언트 노출 |
| 공통 | `.env` 파일 커밋 여부, 시크릿 패턴 스캔 |

### 6. Dependencies

| Stack | 검사 항목 |
|-------|----------|
| BE | `poetry check` / `poetry lock --check` / 미사용 의존성 (deptry) |
| FE | `pnpm audit` / 미사용 의존성 검사 |

### 7. Quality

| Stack | 검사 항목 |
|-------|----------|
| BE | 코드 복잡도, dead code (`vulture`), 네이밍 컨벤션 (snake_case) |
| FE | 컴포넌트 크기, 중복 코드, 네이밍 컨벤션 (camelCase/PascalCase) |
| 공통 | 파일 크기 (300줄 초과 경고), TODO/FIXME 잔존 |

## 통과 기준

- 7단계 모두 통과 → "검증 완료. 커밋 가능."
- 하나라도 실패 → "검증 실패: [실패 항목]. 수정 필요."

## 출력 형식

```
Verify: [N]/7 passed [BE/FE/Fullstack]

| # | 단계 | BE | FE | 상세 |
|---|------|----|----|------|
| 1 | Lint | PASS | PASS | - |
| 2 | Type | PASS | FAIL | FE: 3 errors |
| 3 | Architecture | PASS | - | - |
| 4 | Test | PASS | PASS | BE: 95% cov |
| 5 | Security | PASS | PASS | - |
| 6 | Dependencies | PASS | PASS | - |
| 7 | Quality | WARN | PASS | BE: 1 file >300 lines |

→ [검증 완료 / 검증 실패: 수정 필요 항목]
```

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
