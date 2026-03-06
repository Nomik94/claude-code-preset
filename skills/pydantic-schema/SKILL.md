---
name: pydantic-schema
description: |
  Pydantic v2 DTO/스키마 설계 패턴.
  Use when: 요청/응답 DTO, CamelModel, dto/ 폴더 구조,
  camelCase 변환, alias_generator, model_config, 검증 로직,
  field_validator, model_validator, partial update (apply_simple_fields),
  페이지네이션 응답, 에러 응답 (ErrorBody), from_domain 팩토리,
  Pydantic BaseModel 설정, JSON 직렬화.
  NOT for: 도메인 엔티티 (domain-layer), DB 모델 (sqlalchemy).
---

# Pydantic v2 DTO 패턴

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

dto/는 처음부터 폴더로 생성. endpoint 1:1 파일 매핑.

```
src/{domain}/dto/
  __init__.py          # re-export all DTOs
  create_user.py       # CreateUserRequest, CreateUserResponse
  update_user.py       # UpdateUserRequest
  list_users.py        # ListUsersRequest (query params), UserListItem
  get_user.py          # UserDetailResponse
  common.py            # shared nested schemas (AddressResponse, etc.)
```

- MUST: endpoint당 1개 파일 (create_user.py, list_users.py ...)
- MUST: 단일 dto.py 금지 -- 반드시 폴더 구조
- MUST: `__init__.py`에서 re-export

## Request/Response 패턴

```python
# dto/create_user.py
class CreateUserRequest(CamelModel):
    email: str
    name: str
    password: str
    password_confirm: str

# dto/update_user.py -- partial update
class UpdateUserRequest(CamelModel):
    email: str | None = None
    name: str | None = None
    phone: str | None = None

# dto/get_user.py
class UserDetailResponse(CamelModel):
    id: int
    email: str
    name: str
    role: UserRole
    is_active: bool
    created_at: datetime
```

## apply_simple_fields() -- Partial Update

PATCH 엔드포인트에서 `model_fields_set`을 수동 순회하지 않고 헬퍼 메서드 사용.

```python
class UpdateUserRequest(CamelModel):
    email: str | None = None
    name: str | None = None
    phone: str | None = None

    def apply_simple_fields(self, entity: UserEntity) -> None:
        for field_name in self.model_fields_set:
            setattr(entity, field_name, getattr(self, field_name))
```

- MUST: partial update 시 `apply_simple_fields()` 패턴 사용
- MUST: `model_fields_set` 직접 순회 코드를 서비스 레이어에 노출하지 않음
- 복잡한 필드(비밀번호 해싱 등)는 `apply_simple_fields()` 외부에서 별도 처리

## 페이지네이션

```python
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

Usage: `PaginatedResponse[UserListItem]`

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
- MUST: 필드 에러는 `FieldError` (field + message)
- MUST: `errors` 필드명 사용 (details 금지)
- 422 override 시 `errors`에 각 필드별 FieldError 매핑

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

## Enum 통합

```python
class UserRole(StrEnum):
    ADMIN = "admin"
    MEMBER = "member"
    GUEST = "guest"

class UserDetailResponse(CamelModel):
    role: UserRole  # auto-validates, serializes to string
```

## from_domain 팩토리

ORM `from_attributes` 대신 도메인 엔티티에서 직접 변환할 때 사용.

```python
class UserDetailResponse(CamelModel):
    id: int
    email: str
    name: str

    @classmethod
    def from_domain(cls, entity: "UserEntity") -> Self:
        return cls(
            id=entity.id,
            email=entity.email.value,  # unwrap value objects
            name=entity.name,
        )
```

- MUST: 반환 타입 `Self` (`-> "ClassName"` 금지)
- from_domain은 Response DTO에만 정의

## 직렬화 Quick Reference

| Operation | Code |
|-----------|------|
| ORM -> DTO | `UserDetailResponse.model_validate(db_user)` |
| Entity -> DTO | `UserDetailResponse.from_domain(entity)` |
| DTO -> dict (camel) | `dto.model_dump(by_alias=True, exclude_none=True)` |
| DTO -> JSON string | `dto.model_dump_json(by_alias=True)` |
| Batch convert | `[UserListItem.model_validate(u) for u in db_users]` |

## Checklist

- [ ] CamelModel을 base로 사용 (BaseSchema 아님)
- [ ] dto/ 폴더 구조, endpoint 1:1 파일
- [ ] `__init__.py`에서 모든 DTO re-export
- [ ] Partial update는 `apply_simple_fields()` 패턴
- [ ] 에러 응답은 ErrorBody + FieldError
- [ ] Python 3.13+ 문법: `X | None`, `list[X]`, `StrEnum`
- [ ] Pydantic v2: `model_config`, `model_dump()`, `model_validate()`
- [ ] from_domain 반환 타입 `Self`
- [ ] 도메인 엔티티에 Pydantic import 없음
