# DTO (Pydantic v2) 코드 예시

## CamelModel (Base DTO)

모든 DTO가 상속하는 기반 클래스. 이름은 반드시 `CamelModel`.

```python
from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True,
        alias_generator=to_camel,
    )
```

- MUST: `CamelModel` 명칭 사용 (BaseSchema 금지)
- MUST: 모든 DTO는 CamelModel 상속
- MUST: `from_attributes=True` (ORM 변환용)

## dto/ 폴더 구조

```
{domain}/dto/
  __init__.py          # re-export all DTOs
  create_user.py       # CreateUserRequest, CreateUserResponse
  update_user.py       # UpdateUserRequest
  list_users.py        # ListUsersRequest (query params), UserListItem
  get_user.py          # UserDetailResponse
  common.py            # 공유 nested schemas (AddressResponse 등)
```

## Request/Response 패턴

### Create Request

```python
# dto/create_user.py
class CreateUserRequest(CamelModel):
    email: str
    name: str
    password: str
    password_confirm: str
```

### Update Request (Partial)

```python
# dto/update_user.py
class UpdateUserRequest(CamelModel):
    email: str | None = None
    name: str | None = None
    phone: str | None = None

    def apply_simple_fields(self, entity: UserEntity) -> None:
        """Partial update 헬퍼. model_fields_set 기반."""
        for field_name in self.model_fields_set:
            setattr(entity, field_name, getattr(self, field_name))
```

### Detail Response + from_domain()

```python
# dto/get_user.py
from typing import Self

class UserDetailResponse(CamelModel):
    id: int
    email: str
    name: str
    role: UserRole
    is_active: bool
    created_at: datetime

    @classmethod
    def from_domain(cls, entity: "UserEntity") -> Self:
        return cls(
            id=entity.id,
            email=entity.email.value,
            name=entity.name,
            role=entity.role,
            is_active=entity.is_active,
            created_at=entity.created_at,
        )
```

## 페이지네이션

```python
from typing import Generic, TypeVar
from collections.abc import Sequence
from pydantic import BaseModel, computed_field

T = TypeVar("T", bound=BaseModel)

class PaginatedResponse(CamelModel, Generic[T]):
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
```

## ErrorBody

통일된 에러 응답 구조. 이름은 반드시 `ErrorBody` + `FieldError`.

```python
class FieldError(CamelModel):
    field: str
    message: str

class ErrorBody(CamelModel):
    code: str              # "VALIDATION_ERROR", "NOT_FOUND", "CONFLICT"
    message: str           # human-readable summary
    errors: list[FieldError] = []
```

- MUST: `ErrorBody` 명칭 사용 (ErrorResponse, ErrorDetail 금지)
- MUST: `errors` 필드명 사용 (details 금지)

## Validators

```python
class CreateUserRequest(CamelModel):
    email: str
    password: str
    password_confirm: str

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, v: str) -> str:
        if not re.match(r"^[\w.+-]+@[\w-]+\.[\w.]+$", v):
            raise ValueError("Invalid email format")
        return v.lower().strip()

    @model_validator(mode="after")
    def validate_passwords_match(self) -> Self:
        if self.password != self.password_confirm:
            raise ValueError("Passwords do not match")
        return self
```

- MUST: `field_validator` / `model_validator` 사용 (`@validator` 금지)
- MUST: `model_validator(mode="after")` 반환 타입은 `Self`

## 직렬화 Quick Reference

| Operation | Code |
|-----------|------|
| ORM -> DTO | `UserDetailResponse.model_validate(db_user)` |
| Entity -> DTO | `UserDetailResponse.from_domain(entity)` |
| DTO -> dict (camel) | `dto.model_dump(by_alias=True, exclude_none=True)` |
| DTO -> JSON string | `dto.model_dump_json(by_alias=True)` |
