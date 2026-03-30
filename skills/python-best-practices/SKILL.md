---
name: python-best-practices
description: |
  Use when Python 코드 품질 분석, 타입 힌트 검증, 린팅, 에러 핸들링,
  예외 계층 설계, 의존성 점검, 보안 기본 점검 관련 작업.
  NOT for 아키텍처 리뷰 (reviewer 에이전트), 보안 전문 분석 (/security-audit).
argument-hint: <분석 대상 경로 또는 --quick/--security/--deps>
---

# Python Best Practices

**Python 3.13+ REQUIRED** -- 레거시 타입(`Optional`, `Union`, `List`, `Dict`) 금지.

## 1. 타입 힌트

| Legacy (금지) | Modern (필수) |
|--------------|--------------|
| `Optional[X]` | `X \| None` |
| `Union[X, Y]` | `X \| Y` |
| `List[X]`, `Dict[K,V]`, `Tuple`, `Set` | `list[X]`, `dict[K,V]`, `tuple`, `set` |
| `from typing import List, Dict...` | builtin 제네릭 |
| `from typing import Sequence` | `from collections.abc import Sequence` |
| `-> "ClassName"` (self 반환) | `-> Self` |
| `class Status(str, Enum)` | `class Status(StrEnum)` |
| `@dataclass` | `@dataclass(slots=True)` |

**유지되는 typing imports**: `Generic`, `TypeVar`, `Protocol`, `runtime_checkable`, `Literal`, `Self`, `ClassVar`, `TypeAlias`, `overload`

- [ ] 함수 파라미터/반환 타입 명시
- [ ] `Protocol`, `TypeVar`, `Generic` 적절히 활용
- [ ] 검증: `poetry run mypy --strict app/`

## 2. 코드 품질

### Pydantic v2 필수

| Legacy (금지) | Modern (필수) |
|--------------|--------------|
| `class Config:` | `model_config = ConfigDict(...)` |
| `.dict()` | `model_dump()` |
| `.parse_obj()` | `model_validate()` |
| `@validator` | `field_validator` |

- [ ] Ruff 에러 0건
- [ ] 함수/클래스 복잡도 적정
- [ ] Import 정리 및 정렬
- [ ] 검증: `poetry run ruff check .` / `poetry run ruff format --check .`

## 3. 에러 핸들링

### 파일 배치

| 파일 | 역할 |
|------|------|
| `{domain}/exceptions/domain.py` | 도메인 예외 (HTTP/프레임워크 import 금지) |
| `core/exceptions/base.py` | AppException hierarchy |
| `core/exceptions/handlers.py` | `register_exception_handlers()` |
| `core/exceptions/mappings.py` | 도메인 예외 -> HTTP 상태 코드 매핑 (단일 진실 공급원) |

### 예외 계층

```
AppException (base)
├── NotFoundException       -> 404
├── AlreadyExistsException  -> 409
├── BusinessException       -> 422
├── UnauthorizedException   -> 401
└── ForbiddenException      -> 403
```

- 도메인 예외는 `code: str` + `message: str`만 보유, HTTP 모름
- 도메인별 접두어: `USER_NOT_FOUND`, `ORDER_ALREADY_CANCELLED`

### 매핑 패턴

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

- 매핑 추가 외에 핸들러 로직 수정 금지
- 매핑에 없는 예외는 500 처리

### ErrorBody 응답

| 필드 | 타입 | 설명 |
|------|------|------|
| `code` | `str` | SCREAMING_SNAKE 에러 코드 |
| `message` | `str` | human-readable 메시지 |
| `errors` | `list[FieldError]` | 필드별 검증 에러 (없으면 빈 리스트) |

### 전역 핸들러 등록 순서

1. `RequestValidationError` -> 422 + `VALIDATION_ERROR` + `errors`
2. 도메인 예외 -> `DOMAIN_EXCEPTION_MAPPINGS` 조회
3. `AppException` -> 자체 상태 코드
4. `Exception` -> 500 + prod에서 메시지 숨김

- 모든 핸들러에서 structlog 로깅 (warning 이상)
- 500은 `logger.exception()`으로 스택 트레이스 포함
- prod 500 응답에 내부 메시지 미노출

### 서비스 예외 규칙
- 도메인 예외만 raise, HTTP 상태 코드 직접 지정 금지
- 충분한 컨텍스트 (entity명, ID, 위반 규칙)

### 금지
- 도메인에서 `HTTPException` 직접 raise
- 핸들러에서 매핑 하드코딩 (mappings.py 사용할 것)
- `ErrorBody` 외 다른 에러 형식
- 예외 메시지에 민감 정보

## 4. 보안 기본

> 상세는 `/security-audit` 참조.

- [ ] `poetry run ruff check --select S .`
- [ ] `poetry run pip-audit`

## 5. 의존성 관리

**MUST: Poetry 사용** (pip, uv, pipenv 금지)

- [ ] `pyproject.toml` + `poetry.lock` 커밋됨
- [ ] 버전 범위 적절 (`^`, `~`), 개발 의존성 그룹 분리
- [ ] 미사용 의존성: `poetry run deptry .`
- [ ] 미사용 코드: `poetry run vulture app/`

## 6. 아키텍처 준수

- [ ] `poetry run lint-imports` 통과
- [ ] domain/에 프레임워크 import 없음
- [ ] Conventional Commits 준수, 순환 의존성 없음

## 추가 도구

| 도구 | 용도 |
|------|------|
| vulture | 미사용 코드 탐지 |
| deptry | 미사용/누락 의존성 탐지 |
| pip-audit | 보안 취약점 검사 |
| import-linter | 레이어 간 import 규칙 강제 |

## 출력 형식

```
Python Best Practices Check:
   [{PASS/WARN}] Type Hints: {coverage}% (mypy strict)
   [{PASS/WARN}] Code Quality: {grade} (ruff {n} errors)
   [{PASS/WARN}] Testing: {coverage}% ({n} tests)
   [{PASS/WARN}] Security: {status}
   [{PASS/WARN}] Dependencies: {status}
   [{PASS/WARN}] Architecture: {status}

Score: {score}%
RESULT: {Production Ready | Review Recommended}
```

## 검증 명령어

```bash
poetry run mypy --strict app/
poetry run ruff check . && poetry run ruff format --check .
poetry run pytest --cov=app --cov-report=term-missing
poetry check && poetry lock --check && poetry run deptry .
poetry run vulture app/ && poetry run pip-audit && poetry run lint-imports
```

## 옵션

| 옵션 | 설명 |
|------|------|
| `(기본)` | 전체 분석 |
| `--quick` | 타입 힌트 + 린팅만 |
| `--security` | 보안 집중 |
| `--deps` | 의존성 집중 |
| `--arch` | 아키텍처 준수 |

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
