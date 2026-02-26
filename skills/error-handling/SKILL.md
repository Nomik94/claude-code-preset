---
name: error-handling
description: |
  FastAPI 에러 핸들링 패턴 레퍼런스.
  Use when: 예외 처리, 에러 핸들러, exception handler, 에러 응답,
  커스텀 예외, 도메인 예외를 HTTP로 매핑, 전역 에러 핸들링,
  ValidationError 처리, 404 Not Found, 비즈니스 예외,
  에러 코드 체계, 에러 로깅, 예외 계층 설계.
  NOT for: 보안 관련 예외 (security-audit 참조).
---

# 에러 핸들링 스킬

## 예외 계층 구조

Domain 레이어는 HTTP를 알지 못함. App 레이어가 도메인과 HTTP를 연결.

```python
# domain/exceptions.py — pure domain, zero framework imports
class DomainException(Exception):
    """Base for all domain errors."""
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)

class EntityNotFoundException(DomainException):
    def __init__(self, entity: str, identifier: str | int) -> None:
        super().__init__(
            code=f"{entity.upper()}_NOT_FOUND",
            message=f"{entity} with id '{identifier}' not found",
        )

class BusinessRuleViolation(DomainException):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(code=code, message=message)

class DuplicateEntityException(DomainException):
    def __init__(self, entity: str, field: str, value: str) -> None:
        super().__init__(
            code=f"{entity.upper()}_DUPLICATE",
            message=f"{entity} with {field}='{value}' already exists",
        )

class PermissionDeniedException(DomainException):
    def __init__(self, message: str = "Permission denied") -> None:
        super().__init__(code="PERMISSION_DENIED", message=message)
```

```python
# application/exceptions.py — app layer, knows HTTP
class AppException(Exception):
    """Base for application-layer errors that carry HTTP semantics."""
    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        details: dict | None = None,
    ) -> None:
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details or {}
        super().__init__(message)
```

## 도메인에서 HTTP로의 매핑

| 도메인 예외 | HTTP 상태 | 발생 시점 |
||-------------|------|
| `EntityNotFoundException` | 404 | 리소스 조회 실패 |
| `BusinessRuleViolation` | 422 | 규칙 위반 (예: ORDER_ALREADY_CANCELLED) |
| `DuplicateEntityException` | 409 | 고유 제약 조건 충돌 |
| `PermissionDeniedException` | 403 | 인증됨, 권한 없음 |
| `Unauthorized` (앱 레벨) | 401 | 인증 정보 누락 또는 유효하지 않음 |

```python
# infrastructure/error_mapping.py
DOMAIN_STATUS_MAP: dict[type[DomainException], int] = {
    EntityNotFoundException: 404,
    BusinessRuleViolation: 422,
    DuplicateEntityException: 409,
    PermissionDeniedException: 403,
}

def resolve_status(exc: DomainException) -> int:
    return DOMAIN_STATUS_MAP.get(type(exc), 500)
```

## 에러 응답 형식

모든 에러는 일관된 JSON 형식으로 응답:

```json
{
  "code": "USER_NOT_FOUND",
  "message": "User with id '42' not found",
  "details": {}
}
```

```python
# shared/dto/error.py
from pydantic import BaseModel

class ErrorResponse(BaseModel):
    code: str
    message: str
    details: dict = {}
```

## 에러 코드 규칙

SCREAMING_SNAKE_CASE, 도메인 접두어:

| 도메인 | 예시 |
|--------|---------|
| User | `USER_NOT_FOUND`, `USER_DUPLICATE`, `USER_INACTIVE` |
| Order | `ORDER_NOT_FOUND`, `ORDER_ALREADY_CANCELLED`, `ORDER_EMPTY` |
| Auth | `AUTH_TOKEN_EXPIRED`, `AUTH_INVALID_CREDENTIALS` |
| Common | `VALIDATION_ERROR`, `INTERNAL_ERROR`, `PERMISSION_DENIED` |

## 전역 예외 핸들러

모든 핸들러를 앱 팩토리에 등록.

```python
import structlog
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from starlette.responses import JSONResponse

from domain.exceptions import DomainException
from application.exceptions import AppException
from infrastructure.error_mapping import resolve_status
from shared.dto.error import ErrorResponse
from core.config import settings

logger = structlog.get_logger()

async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    logger.warning("app_exception", code=exc.code, path=request.url.path)
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(code=exc.code, message=exc.message, details=exc.details).model_dump(),
    )

async def domain_exception_handler(request: Request, exc: DomainException) -> JSONResponse:
    status = resolve_status(exc)
    logger.warning("domain_exception", code=exc.code, status=status, path=request.url.path)
    return JSONResponse(
        status_code=status,
        content=ErrorResponse(code=exc.code, message=exc.message).model_dump(),
    )

async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    details = {str(e["loc"]): e["msg"] for e in exc.errors()}
    logger.info("validation_error", path=request.url.path, detail_count=len(details))
    return JSONResponse(
        status_code=422,
        content=ErrorResponse(code="VALIDATION_ERROR", message="Request validation failed", details=details).model_dump(),
    )

async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("unhandled_exception", path=request.url.path, error=str(exc))
    message = "Internal server error" if settings.is_production else str(exc)
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(code="INTERNAL_ERROR", message=message).model_dump(),
    )

def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(AppException, app_exception_handler)
    app.add_exception_handler(DomainException, domain_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)
```

## Application Service에서의 사용

```python
class OrderService:
    async def cancel_order(self, order_id: int, user_id: int) -> None:
        order = await self.repo.find_by_id(order_id)
        if order is None:
            raise EntityNotFoundException("Order", order_id)
        if order.user_id != user_id:
            raise PermissionDeniedException("Cannot cancel another user's order")
        if order.status == OrderStatus.CANCELLED:
            raise BusinessRuleViolation("ORDER_ALREADY_CANCELLED", "Order is already cancelled")
        order.cancel()
        await self.repo.save(order)
```
