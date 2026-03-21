---
name: python-best-practices
description: |
  Use when Python 코드 품질 분석, 타입 힌트 검증, 린팅, 에러 핸들링,
  예외 계층 설계, 의존성 점검, 보안 기본 점검 관련 작업.
  NOT for 아키텍처 리뷰 (reviewer 에이전트), 보안 전문 분석 (/security-audit).
argument-hint: <분석 대상 경로 또는 --quick/--security/--deps>
---

# Python Best Practices 스킬

**Python 3.13+ REQUIRED** -- 레거시 타입(`Optional`, `Union`, `List`, `Dict`) 금지.

---

## 1. 타입 힌트 (Type Hints)

### Modern Python 3.13+ 문법

| Legacy (금지) | Modern (필수) |
|--------------|--------------|
| `Optional[X]` | `X \| None` |
| `Union[X, Y]` | `X \| Y` |
| `List[X]`, `Dict[K,V]`, `Tuple[X,...]`, `Set[X]` | `list[X]`, `dict[K,V]`, `tuple[X,...]`, `set[X]` |
| `from typing import List, Dict, Tuple, Set, Optional, Union` | builtin 제네릭 사용 |
| `from typing import Sequence` | `from collections.abc import Sequence` |
| `-> "ClassName"` (self 반환) | `-> Self` (`from typing import Self`) |
| `class Status(str, Enum)` | `class Status(StrEnum)` |
| `@dataclass` | `@dataclass(slots=True)` |
| `@dataclass(frozen=True)` | `@dataclass(frozen=True, slots=True)` |

**유지되는 `typing` imports** (builtin 대체 없음):
`Generic`, `TypeVar`, `Protocol`, `runtime_checkable`, `Literal`, `Self`, `ClassVar`, `TypeAlias`, `overload`

### MUST 체크

- [ ] 함수 파라미터/반환 타입 명시
- [ ] `Protocol`, `TypeVar`, `Generic` 적절한 활용
- [ ] 검증: `poetry run mypy --strict app/`

---

## 2. 코드 품질 (Code Quality)

### Pydantic v2 필수

| Legacy (금지) | Modern (필수) |
|--------------|--------------|
| `class Config:` | `model_config = ConfigDict(...)` |
| `.dict()` | `model_dump()` |
| `.parse_obj()` | `model_validate()` |
| `@validator` | `field_validator` |

### MUST 체크

- [ ] Ruff 규칙 준수 (에러 0건)
- [ ] 함수/클래스 복잡도 적정 수준
- [ ] Import 정리 및 정렬
- [ ] 검증: `poetry run ruff check .` / `poetry run ruff format --check .`

---

## 3. 에러 핸들링 (Error Handling)

### 파일 배치 규칙

| 파일 | 역할 | 핵심 원칙 |
|------|------|-----------|
| `{domain}/exceptions/domain.py` | 도메인 예외 정의 | HTTP/프레임워크 import 금지 |
| `core/exceptions/base.py` | 공통 예외 베이스 | AppException hierarchy |
| `core/exceptions/handlers.py` | `register_exception_handlers()` | FastAPI app에 핸들러 일괄 등록 |
| `core/exceptions/mappings.py` | `DOMAIN_EXCEPTION_MAPPINGS` dict | 도메인 예외 -> HTTP 상태 코드 매핑의 단일 진실 공급원 |

### 예외 계층 구조

```
AppException (base)
├── NotFoundException       -> 404
├── AlreadyExistsException  -> 409
├── BusinessException       -> 422
├── UnauthorizedException   -> 401
└── ForbiddenException      -> 403
```

도메인 예외 특징:
- `code: str`과 `message: str`만 보유
- HTTP 상태 코드, 프레임워크 타입을 알지 못함
- 도메인별 접두어 사용: `USER_NOT_FOUND`, `ORDER_ALREADY_CANCELLED`

### 매핑 패턴 (mappings.py)

```python
# core/exceptions/mappings.py
DOMAIN_EXCEPTION_MAPPINGS: dict[type[Exception], int] = {
    NotFoundException: 404,
    AlreadyExistsException: 409,
    BusinessException: 422,
    UnauthorizedException: 401,
    ForbiddenException: 403,
    # 새 도메인 예외 = 여기에 1줄 추가
}
```

- MUST: 매핑 추가 외에 핸들러 로직을 수정하지 않는다
- MUST: 매핑에 없는 예외는 500으로 처리

### 에러 응답 형식 (ErrorBody)

| 필드 | 타입 | 설명 |
|------|------|------|
| `code` | `str` | SCREAMING_SNAKE_CASE 에러 코드 |
| `message` | `str` | human-readable 메시지 |
| `errors` | `list[FieldError]` | 필드별 검증 에러 (없으면 빈 리스트) |

에러 코드 규칙:
- SCREAMING_SNAKE_CASE
- 도메인 접두어 필수: `USER_NOT_FOUND`, `ORDER_ALREADY_CANCELLED`
- 공통 코드: `VALIDATION_ERROR`, `INTERNAL_ERROR`, `PERMISSION_DENIED`

### 전역 예외 핸들러 등록 순서

1. `RequestValidationError` -> 422 + `VALIDATION_ERROR` + `errors` 필드
2. 도메인 예외 -> `DOMAIN_EXCEPTION_MAPPINGS`에서 상태 코드 조회
3. `AppException` -> 자체 상태 코드
4. `Exception` -> 500 + prod에서 메시지 숨김

- MUST: 모든 핸들러에서 structlog로 로깅 (warning 이상)
- MUST: 500 에러는 `logger.exception()`으로 스택 트레이스 포함
- MUST: prod 환경에서 500 응답 message에 내부 에러 메시지 미노출

### 서비스에서의 예외 사용

- 서비스 메서드는 도메인 예외만 raise
- HTTP 상태 코드를 서비스에서 직접 지정하지 않음
- 예외에 충분한 컨텍스트 (entity명, ID, 위반 규칙)

### 금지 사항

- 도메인 레이어에서 `HTTPException` 직접 raise 금지
- 핸들러에서 매핑 로직 하드코딩 금지 (mappings.py 사용)
- 에러 응답에서 `ErrorBody` 외 다른 형식 사용 금지
- 예외 메시지에 민감 정보 (비밀번호, 토큰) 포함 금지

---

## 4. 보안 기본

> 보안 상세는 `/security-audit` 참조.

- [ ] Ruff 보안 규칙: `poetry run ruff check --select S .`
- [ ] 의존성 취약점 없음: `poetry run pip-audit`

---

## 5. 의존성 관리

**MUST: Poetry 사용** (pip, uv, pipenv 금지)

- [ ] `pyproject.toml` (Poetry 형식) 존재
- [ ] `poetry.lock` 존재 및 커밋됨
- [ ] 버전 범위 적절히 지정 (`^`, `~`)
- [ ] 개발 의존성 그룹 분리
- [ ] 사용하지 않는 의존성 없음: `poetry run deptry .`
- [ ] 사용하지 않는 코드 없음: `poetry run vulture app/`

---

## 6. 아키텍처 준수

- [ ] import-linter 규칙 준수: `poetry run lint-imports`
- [ ] domain/ 레이어에 프레임워크 import 없음
- [ ] Conventional Commits 형식 준수
- [ ] 순환 의존성 없음

---

## 추가 도구

| 도구 | 용도 | 설치 |
|------|------|------|
| vulture | 사용하지 않는 코드 탐지 | `poetry add --group dev vulture` |
| deptry | 사용하지 않는/누락된 의존성 탐지 | `poetry add --group dev deptry` |
| pip-audit | 의존성 보안 취약점 검사 | `poetry add --group dev pip-audit` |
| import-linter | 레이어 간 import 규칙 강제 | `poetry add --group dev import-linter` |

---

## 출력 형식

### High Quality (>= 90%)

```
Python Best Practices Check:
   [PASS] Type Hints: 95% coverage (mypy strict pass)
   [PASS] Code Quality: A (ruff 0 errors)
   [PASS] Testing: 87% coverage (42 tests)
   [PASS] Security: No issues (pip-audit clean)
   [PASS] Dependencies: All pinned, no unused (deptry clean)
   [PASS] Architecture: import-linter pass

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
```

---

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
poetry run deptry .

# 추가 도구
poetry run vulture app/
poetry run pip-audit
poetry run lint-imports
```

## 옵션

| 옵션 | 설명 |
|------|------|
| `(기본)` | 전체 분석 |
| `--quick` | 타입 힌트 + 린팅만 |
| `--security` | 보안 집중 분석 |
| `--deps` | 의존성 집중 분석 |
| `--arch` | 아키텍처 준수 분석 |

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
