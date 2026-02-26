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

## 분석 카테고리 (5가지)

### 1. Type Hints (25%)

**체크 항목**:
- 함수 파라미터/반환 타입 명시
- Python 3.12+ 문법 사용 (`X | None`, `list[X]`, `Self`)
- `Protocol`, `TypeVar`, `Generic` 적절한 활용

```python
# ❌ Bad
def get_user(id):
    return db.query(id)

# ✅ Good
async def get_user(user_id: int) -> User | None:
    return await db.query(user_id)
```

**검증**: `poetry run mypy --strict app/`

### 2. Code Quality (25%)

**체크 항목**:
- Ruff 규칙 준수
- 함수/클래스 복잡도
- Import 정리
- Python 3.12+ 최신 문법 (StrEnum, dataclass(slots=True) 등)

**검증**: `poetry run ruff check .` / `poetry run ruff format --check .`

### 3. Testing (20%)

**체크 항목**:
- 테스트 파일 존재 (`tests/`)
- 커버리지 ≥80% 권장
- pytest-asyncio 픽스처 사용
- 테스트 피라미드 (Unit > Integration > E2E)

**검증**: `poetry run pytest --cov=app --cov-report=term-missing`

### 4. Security (15%)

**체크 항목**:
- SQL Injection 방지 (SQLAlchemy ORM/바인딩 사용)
- 하드코딩된 시크릿
- 입력 검증 (Pydantic v2)
- OWASP Top 10 패턴

**검증**: `poetry run ruff check --select S .`

### 5. Dependencies (15%)

**필수 규칙**: **Poetry** 사용 (pip, uv, pipenv 금지)

**체크 항목**:
- `pyproject.toml` (Poetry 형식) 존재
- `poetry.lock` 존재 및 커밋됨
- 버전 범위 적절히 지정 (`^`, `~`)
- 개발 의존성 그룹 분리

**검증**: `poetry check` / `poetry lock --check`

## 출력 형식

### High Quality (≥90%)
```
📋 Python Best Practices Check:
   ✅ Type Hints: 95% coverage (mypy strict pass)
   ✅ Code Quality: A (ruff 0 errors)
   ✅ Testing: 87% coverage (42 tests)
   ✅ Security: No issues
   ✅ Dependencies: All pinned, no vulnerabilities

📊 Score: 0.94 (94%)
✅ Production Ready
```

### Needs Improvement (70-89%)
```
📋 Python Best Practices Check:
   ✅ Type Hints: 78% coverage
   ⚠️  Code Quality: B (12 ruff warnings)
   ✅ Testing: 72% coverage
   ⚠️  Security: 2 low-severity issues
   ✅ Dependencies: OK

📊 Score: 0.76 (76%)
⚠️  Review Recommended

💡 개선 필요:
1. src/utils.py:45 - 타입 힌트 누락
2. src/api.py:120 - 복잡도 높음 (리팩토링 권장)
```

### Poor Quality (<70%)
```
📋 Python Best Practices Check:
   ❌ Type Hints: 32% coverage
   ❌ Code Quality: D (47 errors)
   ❌ Testing: 15% coverage (3 tests)
   ⚠️  Security: 5 issues
   ❌ Dependencies: Unpinned versions

📊 Score: 0.42 (42%)
❌ Not Ready for Review
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
```

## 옵션

| 옵션 | 설명 |
|------|------|
| `(기본)` | 전체 5 카테고리 분석 |
| `--quick` | 타입 힌트 + 린팅만 |
| `--security` | 보안 집중 분석 |
| `--deps` | 의존성 집중 분석 |
