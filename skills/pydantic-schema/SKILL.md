---
name: pydantic-schema
description: |
  Pydantic v2 스키마 패턴 레퍼런스.
  Use when: 요청/응답 스키마, Request DTO, Response DTO, 스키마 설계,
  camelCase 변환, alias_generator, model_config, 검증 로직,
  커스텀 validator, field_validator, model_validator,
  중첩 스키마, 페이지네이션 응답, 에러 응답 포맷,
  Pydantic BaseModel 설정, JSON 직렬화, 역직렬화.
  NOT for: 도메인 엔티티 (domain-layer 참조), DB 모델 (sqlalchemy 참조).
---

# Pydantic v2 스키마 패턴

## Base 스키마 설정

```python
from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel

class BaseSchema(BaseModel):
    """All DTOs inherit this. JSON uses camelCase, Python uses snake_case."""
    model_config = ConfigDict(
        from_attributes=True,       # ORM model -> schema
        populate_by_name=True,      # accept both camelCase and snake_case
        alias_generator=to_camel,   # snake_case -> camelCase in JSON
    )
```

## 스키마 상속 패턴

```python
class UserBase(BaseSchema):
    """Shared fields across Create/Update/Response."""
    email: str
    name: str

class CreateUserRequest(UserBase):
    """Fields required only on creation."""
    password: str
    password_confirm: str

class UpdateUserRequest(BaseSchema):
    """All Optional for partial update (PATCH)."""
    email: str | None = None
    name: str | None = None
    phone: str | None = None

class UserResponse(UserBase):
    """Response with DB-generated fields."""
    id: int
    role: "UserRole"
    is_active: bool
    created_at: datetime
```

## 페이지네이션 패턴

```python
from collections.abc import Sequence
from typing import Generic, TypeVar
from pydantic import BaseModel, ConfigDict, computed_field
from pydantic.alias_generators import to_camel

T = TypeVar("T", bound=BaseModel)

class PaginatedResponse(BaseModel, Generic[T]):
    """Generic pagination wrapper. Usage: PaginatedResponse[UserResponse]"""
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    items: Sequence[T]
    total: int
    page: int
    size: int

    @computed_field  # type: ignore[prop-decorator]
    @property
    def total_pages(self) -> int:
        return (self.total + self.size - 1) // self.size if self.size > 0 else 0

    @computed_field  # type: ignore[prop-decorator]
    @property
    def has_next(self) -> bool:
        return self.page < self.total_pages

# Router usage:
# @router.get("", response_model=PaginatedResponse[UserResponse])
```

## 에러 응답 형식

```python
class ErrorDetail(BaseSchema):
    field: str | None = None
    message: str

class ErrorResponse(BaseSchema):
    """Consistent error format across all endpoints."""
    code: str          # e.g. "VALIDATION_ERROR", "NOT_FOUND"
    message: str       # human-readable
    details: list[ErrorDetail] = []

# 422 override example in exception handler:
# {"code": "VALIDATION_ERROR", "message": "Invalid input", "details": [...]}
```

## 검증기

```python
import re
from pydantic import field_validator, model_validator

class CreateUserRequest(UserBase):
    password: str
    password_confirm: str

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, v: str) -> str:
        pattern = r"^[\w.+-]+@[\w-]+\.[\w.]+$"
        if not re.match(pattern, v):
            raise ValueError("Invalid email format")
        return v.lower().strip()

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain uppercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain a digit")
        return v

    @model_validator(mode="after")
    def validate_passwords_match(self) -> Self:
        if self.password != self.password_confirm:
            raise ValueError("Passwords do not match")
        return self
```

## Enum 통합

```python
from enum import StrEnum

class UserRole(StrEnum):
    ADMIN = "admin"
    MEMBER = "member"
    GUEST = "guest"

class UserResponse(UserBase):
    id: int
    role: UserRole          # serializes to "admin", "member", etc.
    is_active: bool
    created_at: datetime

# Request with enum constraint:
class UpdateRoleRequest(BaseSchema):
    role: UserRole          # auto-validates against enum values
```

## 직렬화

```python
# Schema -> JSON dict (camelCase keys, no None values)
user = UserResponse.model_validate(orm_user)
json_dict = user.model_dump(by_alias=True, exclude_none=True)
# {"id": 1, "email": "a@b.com", "name": "Kim", "role": "admin", "isActive": true, "createdAt": "..."}

# JSON string
json_str = user.model_dump_json(by_alias=True, exclude_none=True)

# From dict/JSON (accepts both camelCase and snake_case)
user = UserResponse.model_validate({"id": 1, "email": "a@b.com", "name": "Kim", ...})

# From ORM model (requires from_attributes=True)
user = UserResponse.model_validate(db_user)

# Batch conversion
users = [UserResponse.model_validate(u) for u in db_users]
```

## 중첩 스키마

```python
class AddressResponse(BaseSchema):
    city: str
    street: str
    zip_code: str

class UserDetailResponse(UserResponse):
    """Extended response with nested relations."""
    addresses: list[AddressResponse] = []
    department: "DepartmentResponse | None" = None

# ORM model with relationships -> nested schema automatically
# requires from_attributes=True and eager/joined load on query
```

## from_domain 팩토리

```python
class UserResponse(UserBase):
    id: int
    role: UserRole
    is_active: bool
    created_at: datetime

    @classmethod
    def from_domain(cls, entity: "UserEntity") -> Self:
        """Domain entity -> Response DTO (when not using ORM mode)."""
        return cls(
            id=entity.id,
            email=entity.email.value,  # unwrap value objects
            name=entity.name,
            role=UserRole(entity.role.value),
            is_active=entity.is_active,
            created_at=entity.created_at,
        )
```
