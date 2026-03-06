---
name: error-handling
description: |
  FastAPI 에러 핸들링 패턴 레퍼런스.
  Use when: 예외 처리, 에러 핸들러, exception handler, 에러 응답,
  커스텀 예외, 도메인 예외를 HTTP로 매핑, 전역 에러 핸들링,
  ValidationError 처리, 404 Not Found, 비즈니스 예외,
  에러 코드 체계, 에러 로깅, 예외 계층 설계,
  mappings.py, DOMAIN_EXCEPTION_MAPPINGS, ErrorBody,
  @transactional, @retry, @log_execution.
  NOT for: 보안 관련 예외 (security-audit 참조).
---

# 에러 핸들링 스킬

## 1. 파일 배치 규칙

| 파일 | 역할 | 핵심 원칙 |
|------|------|-----------|
| `{domain}/exceptions/domain.py` | 도메인 예외 정의 | HTTP/프레임워크 import 금지 |
| `core/exceptions/base.py` | 공통 예외 베이스 클래스 | AppException, NotFoundException, AlreadyExistsException, BusinessException, UnauthorizedException, ForbiddenException |
| `core/exceptions/handlers.py` | `register_exception_handlers()` | FastAPI app에 핸들러 일괄 등록 |
| `core/exceptions/mappings.py` | `DOMAIN_EXCEPTION_MAPPINGS` dict | 도메인 예외 -> HTTP 상태 코드 매핑의 단일 진실 공급원 |

MUST: 도메인 예외 파일에는 `fastapi`, `starlette`, `sqlalchemy` import가 없어야 한다.

MUST: 새 도메인 예외 추가 시 `mappings.py`에 1줄만 추가한다. 핸들러 코드 수정 금지.

## 2. 예외 계층 구조

### 도메인 예외 (순수)

- `{domain}/exceptions/domain.py`에 위치
- `code: str`과 `message: str`만 보유
- HTTP 상태 코드, 프레임워크 타입을 알지 못함
- 도메인별 접두어 사용 (예: `ORDER_NOT_FOUND`, `USER_DUPLICATE`)

### 코어 예외 (base.py)

`core/exceptions/base.py`에 정의되는 공통 예외:

| 클래스 | 용도 |
|--------|------|
| `AppException` | 모든 애플리케이션 예외의 베이스 |
| `NotFoundException` | 리소스 조회 실패 |
| `AlreadyExistsException` | 고유 제약 조건 충돌 |
| `BusinessException` | 비즈니스 규칙 위반 |
| `UnauthorizedException` | 인증 정보 누락/무효 |
| `ForbiddenException` | 인증됨, 권한 없음 |

## 3. 매핑 패턴 (mappings.py)

`core/exceptions/mappings.py`에 `DOMAIN_EXCEPTION_MAPPINGS` dict 하나로 관리한다.

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

MUST: 매핑 추가 외에 핸들러 로직을 수정하지 않는다.

MUST: 매핑에 없는 예외는 500으로 처리된다.

## 4. 에러 응답 형식 (ErrorBody)

모든 에러 응답은 `ErrorBody` 스키마를 따른다:

| 필드 | 타입 | 설명 |
|------|------|------|
| `code` | `str` | SCREAMING_SNAKE_CASE 에러 코드 |
| `message` | `str` | 사람이 읽을 수 있는 메시지 |
| `errors` | `list[FieldError]` | 필드별 검증 에러 목록 (없으면 빈 리스트) |

### 에러 코드 규칙

- SCREAMING_SNAKE_CASE
- 도메인 접두어 필수: `USER_NOT_FOUND`, `ORDER_ALREADY_CANCELLED`
- 공통 코드: `VALIDATION_ERROR`, `INTERNAL_ERROR`, `PERMISSION_DENIED`

## 5. 전역 예외 핸들러 등록

`core/exceptions/handlers.py`에 `register_exception_handlers(app)` 함수를 정의한다.

등록 순서 (구체적 -> 일반적):
1. `RequestValidationError` -> 422 + `VALIDATION_ERROR` + `errors` 필드 채움
2. 도메인 예외 -> `DOMAIN_EXCEPTION_MAPPINGS`에서 상태 코드 조회
3. `AppException` -> 자체 상태 코드 사용
4. `Exception` -> 500 + prod에서는 메시지 숨김

MUST: 모든 핸들러에서 structlog로 로깅한다 (warning 이상).

MUST: 500 에러는 `logger.exception()`으로 스택 트레이스를 포함한다.

MUST: prod 환경에서 500 응답 message에 내부 에러 메시지를 노출하지 않는다.

## 6. 데코레이터 (common/decorators.py)

`common/decorators.py`에 세 가지 서비스 데코레이터를 정의한다:

| 데코레이터 | 역할 |
|-----------|------|
| `@transactional` | DB 트랜잭션 래핑 (commit/rollback) |
| `@retry` | 재시도 로직 (일시적 오류 대응) |
| `@log_execution` | 실행 시간/결과 로깅 |

### 데코레이터 적용 순서

MUST: 다음 순서를 준수한다 (위에서 아래로 = 바깥에서 안쪽):

```
@log_execution    # 1. 최외곽: 전체 실행 로깅
@retry            # 2. 중간: 실패 시 재시도
@transactional    # 3. 최내곽: DB 트랜잭션
async def some_service_method(...):
```

이유: `@log_execution`이 재시도 포함 전체 시간을 측정하고, `@retry`가 트랜잭션 단위로 재시도한다.

## 7. 서비스에서의 예외 사용

- 서비스 메서드는 도메인 예외만 raise한다
- HTTP 상태 코드를 서비스에서 직접 지정하지 않는다
- 예외에 충분한 컨텍스트를 담는다 (entity명, ID, 위반 규칙)

## 8. 검증 체크리스트

### 새 도메인 예외 추가 시

- [ ] `{domain}/exceptions/domain.py`에 예외 클래스 정의
- [ ] HTTP/프레임워크 import 없음 확인
- [ ] `code`와 `message` 필드 포함
- [ ] `core/exceptions/mappings.py`의 `DOMAIN_EXCEPTION_MAPPINGS`에 1줄 추가
- [ ] 에러 코드는 SCREAMING_SNAKE_CASE + 도메인 접두어

### 핸들러 검증

- [ ] `register_exception_handlers()`가 앱 팩토리에서 호출됨
- [ ] 모든 핸들러가 `ErrorBody` 형식으로 응답
- [ ] 500 에러에 `logger.exception()` 사용
- [ ] prod에서 내부 에러 메시지 미노출
- [ ] `errors` 필드: ValidationError에서만 채움, 나머지는 빈 리스트

### 데코레이터 검증

- [ ] 순서: `@log_execution` -> `@retry` -> `@transactional`
- [ ] `@transactional`은 `AsyncSession` 사용
- [ ] `@retry`에 최대 재시도 횟수와 대상 예외 타입 지정
- [ ] `@log_execution`에 structlog 사용

## 9. 금지 사항

- 도메인 레이어에서 `HTTPException` 직접 raise 금지
- 핸들러에서 매핑 로직 하드코딩 금지 (mappings.py 사용)
- 에러 응답에서 `ErrorBody` 외 다른 형식 사용 금지
- `@transactional`을 `@log_execution`보다 바깥에 배치 금지
- 예외 메시지에 민감 정보 (비밀번호, 토큰) 포함 금지
