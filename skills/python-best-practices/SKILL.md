---
name: python-best-practices
description: |
  Python 코드 리뷰 및 베스트 프랙티스 검증.
  Use when: /python-best-practices, 코드 품질 분석, .py 파일 리뷰,
  타입 힌트 검증, 린팅, 테스트 커버리지 분석, 의존성 점검.
  NOT for: 아키텍처 리뷰 (/code-review), 보안 전문 분석 (/security-audit).
argument-hint: <분석 대상 경로 또는 --quick/--security/--deps>
---

# Python Best Practices Skill

Python 코드의 품질, 타입 안전성, 테스트 커버리지, 린팅 규칙 준수를 종합적으로 분석합니다.

**Python 3.13+ REQUIRED** — 레거시 타입(`Optional`, `Union`, `List`, `Dict`) 금지.

## 분석 카테고리 (6가지)

### 1. Type Hints (20%)

**MUST 체크 항목**:
- [ ] 함수 파라미터/반환 타입 명시
- [ ] Python 3.13+ 문법 사용 (`X | None`, `list[X]`, `Self`)
- [ ] `Protocol`, `TypeVar`, `Generic` 적절한 활용
- [ ] `Optional`, `Union`, `List`, `Dict` 등 레거시 타입 금지

**검증**: `poetry run mypy --strict app/`

### 2. Code Quality (20%)

**MUST 체크 항목**:
- [ ] Ruff 규칙 준수 (에러 0건)
- [ ] 함수/클래스 복잡도 적정 수준
- [ ] Import 정리 및 정렬
- [ ] Python 3.13+ 최신 문법 (StrEnum, `dataclass(slots=True)` 등)
- [ ] Pydantic v2 필수 패턴:
  - `model_config = ConfigDict(...)` (not `class Config:`)
  - `model_dump()` / `model_validate()` (not `.dict()` / `.parse_obj()`)
  - `field_validator` / `model_validator` (not `@validator`)
  - `from_attributes=True` (not `orm_mode = True`)

**Ruff select 기준**: `E`, `W`, `F`, `I`, `N`, `UP`, `S`, `B`, `A`, `C4`, `DTZ`, `T20`, `ICN`, `PIE`, `PT`, `RSE`, `RET`, `SLF`, `SIM`, `TID`, `ARG`, `ERA`, `PL`, `RUF`, `ANN`, `TID`

**검증**: `poetry run ruff check .` / `poetry run ruff format --check .`

### 3. Testing (15%)

**MUST 체크 항목**:
- [ ] 테스트 파일 존재 (`tests/`)
- [ ] 커버리지 >= 80%
- [ ] pytest-asyncio 픽스처 사용
- [ ] 테스트 피라미드 (Unit > Integration > E2E)

**검증**: `poetry run pytest --cov=app --cov-report=term-missing`

### 4. Security (15%)

**MUST 체크 항목**:
- [ ] SQL Injection 방지 (SQLAlchemy ORM/바인딩 사용)
- [ ] 하드코딩된 시크릿 없음
- [ ] 입력 검증 (Pydantic v2)
- [ ] OWASP Top 10 패턴
- [ ] 의존성 취약점 없음 (pip-audit)

**검증**: `poetry run ruff check --select S .` / `poetry run pip-audit`

### 5. Dependencies (15%)

**MUST 규칙**: **Poetry** 사용 (pip, uv, pipenv 금지)

**MUST 체크 항목**:
- [ ] `pyproject.toml` (Poetry 형식) 존재
- [ ] `poetry.lock` 존재 및 커밋됨
- [ ] 버전 범위 적절히 지정 (`^`, `~`)
- [ ] 개발 의존성 그룹 분리
- [ ] 사용하지 않는 의존성 없음 (deptry)
- [ ] 사용하지 않는 코드 없음 (vulture)

**검증**: `poetry check` / `poetry lock --check` / `poetry run deptry .` / `poetry run vulture app/`

### 6. Architecture Compliance (15%)

**MUST 체크 항목**:
- [ ] import-linter 규칙 준수 (레이어 간 의존성 방향)
- [ ] domain/ 레이어에 프레임워크 import 없음
- [ ] Conventional Commits 형식 준수
- [ ] 순환 의존성 없음

**검증**: `poetry run lint-imports` / `git log --oneline -10` (커밋 메시지 형식 확인)

## 추가 도구

| 도구 | 용도 | 설치 |
|------|------|------|
| vulture | 사용하지 않는 코드 탐지 | `poetry add --group dev vulture` |
| deptry | 사용하지 않는/누락된 의존성 탐지 | `poetry add --group dev deptry` |
| pip-audit | 의존성 보안 취약점 검사 | `poetry add --group dev pip-audit` |
| import-linter | 레이어 간 import 규칙 강제 | `poetry add --group dev import-linter` |

## 출력 형식

### High Quality (>= 90%)
```
Python Best Practices Check:
   [PASS] Type Hints: 95% coverage (mypy strict pass)
   [PASS] Code Quality: A (ruff 0 errors)
   [PASS] Testing: 87% coverage (42 tests)
   [PASS] Security: No issues (pip-audit clean)
   [PASS] Dependencies: All pinned, no unused (deptry clean)
   [PASS] Architecture: import-linter pass, Conventional Commits OK

Score: 0.94 (94%)
RESULT: Production Ready
```

### Needs Improvement (70-89%)
```
Python Best Practices Check:
   [PASS] Type Hints: 78% coverage
   [WARN] Code Quality: B (12 ruff warnings)
   [PASS] Testing: 72% coverage
   [WARN] Security: 2 low-severity issues
   [PASS] Dependencies: OK
   [WARN] Architecture: 1 import-linter violation

Score: 0.76 (76%)
RESULT: Review Recommended

Improvements:
1. src/utils.py:45 - 타입 힌트 누락
2. src/api.py:120 - 복잡도 높음 (리팩토링 권장)
3. domain/service.py - SQLAlchemy import 감지 (domain purity 위반)
```

### Poor Quality (< 70%)
```
Python Best Practices Check:
   [FAIL] Type Hints: 32% coverage
   [FAIL] Code Quality: D (47 errors)
   [FAIL] Testing: 15% coverage (3 tests)
   [WARN] Security: 5 issues
   [FAIL] Dependencies: Unpinned versions, 3 unused deps
   [FAIL] Architecture: 4 import violations

Score: 0.42 (42%)
RESULT: Not Ready for Review
```

## 검증 명령어

```bash
# 전체 분석
poetry run mypy --strict app/
poetry run ruff check .
poetry run ruff format --check .
poetry run pytest --cov=app --cov-report=term-missing

# 의존성 점검
poetry check
poetry lock --check
poetry show --outdated
poetry run deptry .

# 추가 도구
poetry run vulture app/
poetry run pip-audit
poetry run lint-imports

# Conventional Commits 검증
git log --oneline -20 | grep -vE '^[a-f0-9]+ (feat|fix|refactor|docs|test|chore|ci|perf|build|style|revert)(\(.+\))?!?:'
```

## 옵션

| 옵션 | 설명 |
|------|------|
| `(기본)` | 전체 6 카테고리 분석 |
| `--quick` | 타입 힌트 + 린팅만 |
| `--security` | 보안 집중 분석 (pip-audit 포함) |
| `--deps` | 의존성 집중 분석 (deptry, vulture 포함) |
| `--arch` | 아키텍처 준수 분석 (import-linter 포함) |
