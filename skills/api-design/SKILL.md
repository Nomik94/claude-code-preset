---
name: api-design
description: |
  RESTful API 설계 및 버저닝 패턴 레퍼런스.
  Use when: API 설계, REST API, 엔드포인트 설계, URL 설계, HTTP 메서드,
  리소스 네이밍, 상태 코드, 필터링, 정렬, 검색,
  API 응답 구조, 벌크 작업, idempotency, API 컨벤션,
  API 버전 관리, v1/v2 경로 설정, 버전 올리기, 버전 분리,
  EndpointPath 헬퍼 사용법, 엔드포인트 경로 규칙, 하드코딩 경로 금지,
  admin/app/web 분리, Sub-Application, 클라이언트별 Swagger, 클라이언트별 미들웨어,
  app.mount, 서브앱 구조, deprecated API, sunset, deprecation 처리.
  파라미터 클래스, Depends 파라미터, PaginationParams, PathParams,
  Query/Path 파라미터 묶기, 파라미터 재사용, 핸들러 시그니처 정리.
  NOT for: Pydantic 스키마 (pydantic-schema 참조), 에러 핸들링 설계 (error-handling 참조).
---

# RESTful API 설계 패턴

## URL 패턴 & 버저닝

```
/{client}/v{version}/{domain}/{action}
```

| 세그먼트 | 설명 | 예시 |
|---------|------|------|
| `client` | 클라이언트 유형 | `admin`, `app`, `web` |
| `version` | API 버전 | `v1`, `v2` |
| `domain` | 서비스 도메인 | `attendance`, `users` |
| `action` | 엔드포인트 | `/list`, `/detail/{id}` |

### EndpointPath 헬퍼

```python
class EndpointPath:
    def __init__(self, client: str, domain: str, default_version: int = 1):
        self.client = client
        self.domain = domain
        self.default_version = default_version

    def __call__(self, action: str, *, v: int | None = None) -> str:
        version = v or self.default_version
        if not action.startswith("/"): action = f"/{action}"
        return f"/{self.client}/v{version}/{self.domain}{action}"

def admin(domain: str, **kwargs) -> EndpointPath:
    return EndpointPath("admin", domain, **kwargs)
def app(domain: str, **kwargs) -> EndpointPath:
    return EndpointPath("app", domain, **kwargs)
def web(domain: str, **kwargs) -> EndpointPath:
    return EndpointPath("web", domain, **kwargs)
```

### 사용법

```python
from core.util.versioning import admin
router = APIRouter()
api = admin("attendance")

@router.get(api("/list"))              # /admin/v1/attendance/list
@router.get(api("/detail/{id}"))       # /admin/v1/attendance/detail/{id}
@router.get(api("/list", v=2))         # /admin/v2/attendance/list
```

## Sub-Application 구조

```python
app = FastAPI(docs_url=None)
admin_app = FastAPI(title="Admin API")
app_app = FastAPI(title="App API")
web_app = FastAPI(title="Web API")

app.mount("/admin", admin_app)  # /admin/docs → Admin Swagger
app.mount("/app", app_app)      # /app/docs → App Swagger
app.mount("/web", web_app)      # /web/docs → Web Swagger
```

### 클라이언트별 미들웨어

```python
app.add_middleware(CORSMiddleware, ...)      # Global
admin_app.add_middleware(AdminAuthMiddleware) # /admin/** only
app_app.add_middleware(JWTMobileAuth)         # /app/** only
web_app.add_middleware(WebSessionMiddleware)  # /web/** only
```

## 리소스 네이밍 규칙

| 금지 패턴 | 올바른 패턴 | 이유 |
|-----------|------------|------|
| `/getUsers` | `GET api("/list")` | 동사는 HTTP 메서드로 표현 |
| `/user` | `/users` | 컬렉션은 복수형 |
| `/user_list` | `api("/list")` | list/all 접미사 불필요 |
| `/userOrders` | `api("/{id}/orders")` | camelCase 금지, 중첩 사용 |
| `/Users` | `/users` | 소문자 kebab-case 필수 |
| 하드코딩 경로 | `EndpointPath` 사용 | CI 린트 강제 |

```
# 중첩 리소스 (소유 관계) — 최대 2단계
GET  api("/{user_id}/orders")              # 사용자의 주문 목록
POST api("/{user_id}/orders")              # 사용자에게 주문 생성
GET  api("/{user_id}/orders/{order_id}")   # 특정 주문 조회

# 최대 2단계 초과 → 쿼리 파라미터로 대체
# BAD:  /users/{id}/orders/{id}/items/{id}/reviews
# GOOD: /reviews?order_item_id={id}
```

## HTTP 메서드 & 상태 코드

| 메서드 | 용도 | 성공 코드 | Idempotent | Safe |
|--------|------|-----------|------------|------|
| GET | 조회 | 200 | Yes | Yes |
| POST | 생성 | 201 + Location | No | No |
| PUT | 전체 교체 | 200 | Yes | No |
| PATCH | 부분 수정 | 200 | No* | No |
| DELETE | 삭제 | 204 (no body) | Yes | No |

### 상태 코드 가이드

```python
# 2xx Success
200  # OK — GET, PUT, PATCH 성공
201  # Created — POST 성공 (Location 헤더 포함)
204  # No Content — DELETE 성공, 응답 본문 없음

# 4xx Client Error
400  # Bad Request — 잘못된 요청 본문/파라미터
401  # Unauthorized — 인증 필요 (토큰 없음/만료)
403  # Forbidden — 인증됨, 권한 부족
404  # Not Found — 리소스 없음
409  # Conflict — 중복 생성, 상태 충돌, 핸들링 되고 있는 비즈니스 로직의 예외처리
422  # Unprocessable Entity — 유효성 검증 실패 (FastAPI 기본)
429  # Too Many Requests — Rate Limit 초과

# 5xx Server Error
500  # Internal Server Error — 서버 버그
503  # Service Unavailable — 일시적 서비스 불가
```

## 파라미터 클래스 패턴 (Depends)

라우터 핸들러에 Path/Query 파라미터를 직접 나열하면 시그니처가 비대해지고 재사용이 불가능.
**반드시 Pydantic BaseModel + `Depends()`로 파라미터를 클래스로 묶어서 사용.**

### 공통 파라미터 클래스

```python
from fastapi import Path, Query
from pydantic import BaseModel, ConfigDict


class PaginationParams(BaseModel):
    """모든 목록 API에서 재사용하는 페이지네이션 파라미터."""

    model_config = ConfigDict(populate_by_name=True)

    page: int = Query(1, ge=1, description="Page number")
    size: int = Query(20, ge=1, le=100, description="Items per page")
    sort: str = Query("created_at", description="Sort field")
    order: str = Query("desc", pattern="^(asc|desc)$")
```

### 도메인별 확장

```python
from enum import StrEnum


class UserStatus(StrEnum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"


class UserRole(StrEnum):
    ADMIN = "admin"
    USER = "user"
    MANAGER = "manager"


class UserListParams(PaginationParams):
    """사용자 목록 조회 전용 필터 파라미터."""

    status: UserStatus | None = Query(None, description="Filter by status")
    role: UserRole | None = Query(None, description="Filter by role")
    search: str | None = Query(None, description="Search keyword")


class UserPathParams(BaseModel):
    """사용자 단일 리소스 경로 파라미터."""

    user_id: int = Path(..., gt=0, description="User ID")
```

### 라우터 적용

```python
from fastapi import APIRouter, Depends, status
from fastapi.responses import Response
from core.util.versioning import app

router = APIRouter()
api = app("users")


# GET /app/v1/users/list
@router.get(api("/list"), response_model=PaginatedResponse[UserResponse])
async def list_users(
    params: UserListParams = Depends(),
    service: UserService = Depends(get_user_service),  # Application Service
) -> PaginatedResponse[UserResponse]:
    return await service.list_users(
        page=params.page,
        size=params.size,
        sort=params.sort,
        order=params.order,
        status=params.status,
        role=params.role,
        search=params.search,
    )


# GET /app/v1/users/detail/{user_id}
@router.get(api("/detail/{user_id}"), response_model=UserResponse)
async def get_user(
    path: UserPathParams = Depends(),
    service: UserService = Depends(get_user_service),
) -> UserResponse:
    return await service.get_user(path.user_id)


# POST /app/v1/users/create
@router.post(api("/create"), response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    body: CreateUserRequest,
    service: UserService = Depends(get_user_service),
) -> UserResponse:
    return await service.create_user(body)


# PATCH /app/v1/users/update/{user_id}
@router.patch(api("/update/{user_id}"), response_model=UserResponse)
async def update_user(
    path: UserPathParams = Depends(),
    body: UpdateUserRequest,
    service: UserService = Depends(get_user_service),
) -> UserResponse:
    return await service.update_user(path.user_id, body)


# DELETE /app/v1/users/delete/{user_id}
@router.delete(api("/delete/{user_id}"), status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    path: UserPathParams = Depends(),
    service: UserService = Depends(get_user_service),
) -> Response:
    await service.delete_user(path.user_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
```

### 중첩 리소스 라우터

```python
from core.util.versioning import app

router = APIRouter()
api = app("users")


class UserOrderListParams(PaginationParams):
    """사용자의 주문 목록 조회 파라미터."""

    user_id: int = Path(..., gt=0, description="User ID")


# GET /app/v1/users/{user_id}/orders
@router.get(api("/{user_id}/orders"), response_model=PaginatedResponse[OrderResponse])
async def list_user_orders(
    params: UserOrderListParams = Depends(),
    service: OrderService = Depends(get_order_service),
) -> PaginatedResponse[OrderResponse]:
    return await service.list_by_user(
        params.user_id, page=params.page, size=params.size,
    )
```

### 금지 패턴

```python
# BAD: 라우터 핸들러에 Query/Path 직접 나열
@router.get(api("/list"))
async def list_users(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    sort: str = Query("created_at"),
    order: str = Query("desc"),
    status: str | None = Query(None),
    role: str | None = Query(None),
    search: str | None = Query(None),        # 시그니처 비대, 재사용 불가
    service: UserService = Depends(get_user_service),
) -> PaginatedResponse[UserResponse]: ...

# GOOD: 파라미터 클래스로 묶어서 Depends() 사용
@router.get(api("/list"))
async def list_users(
    params: UserListParams = Depends(),      # 깔끔, 재사용 가능
    service: UserService = Depends(get_user_service),
) -> PaginatedResponse[UserResponse]: ...
```

## 필터링, 정렬, 검색

```python
# Query parameter 패턴
GET /app/v1/users/list?status=active&role=admin          # 필터링
GET /app/v1/users/list?sort=created_at&order=desc        # 정렬
GET /app/v1/users/list?search=kim                        # 검색
GET /app/v1/users/list?page=2&size=20                    # 페이지네이션

# 다중 값 필터
GET /app/v1/orders/list?status=pending&status=processing
# FastAPI: status: list[str] = Query(default=[])

# 날짜 범위
GET /app/v1/orders/list?created_after=2026-01-01&created_before=2026-02-01

# 금지: 필터를 URL path에 넣지 않음
# BAD:  GET /app/v1/users/active
# GOOD: GET /app/v1/users/list?status=active
```

### 정렬 패턴

```python
# 방법 1: sort + order (단순, 권장)
GET /app/v1/users/list?sort=name&order=asc

# 방법 2: prefix 방식 (다중 정렬)
GET /app/v1/users/list?sort=-created_at,name   # created_at DESC, name ASC
```

## 벌크 작업

```python
from core.util.versioning import admin

router = APIRouter()
api = admin("users")

# POST /admin/v1/users/bulk-delete
@router.post(api("/bulk-delete"), status_code=status.HTTP_204_NO_CONTENT)
async def bulk_delete_users(
    body: BulkDeleteRequest,  # {"ids": [1, 2, 3]}
    service: UserService = Depends(get_user_service),
) -> Response:
    await service.bulk_delete(body.ids)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# POST /admin/v1/users/bulk-update-status
@router.post(api("/bulk-update-status"), response_model=BulkOperationResponse)
async def bulk_update_status(
    body: BulkStatusUpdateRequest,  # {"ids": [1, 2, 3], "status": "inactive"}
    service: UserService = Depends(get_user_service),
) -> BulkOperationResponse:
    return await service.bulk_update_status(body)


class BulkOperationResponse(BaseSchema):
    """Partial success 지원."""
    succeeded: list[int]
    failed: list[BulkErrorDetail]
    total: int
    success_count: int
```

## 비-CRUD 액션

```python
from core.util.versioning import app

router = APIRouter()
order_api = app("orders")
user_api = app("users")

# 방법 1: 서브리소스 액션 패턴 (복잡한 비즈니스 로직)
@router.post(order_api("/{order_id}/cancel"))     # /app/v1/orders/{order_id}/cancel
@router.post(order_api("/{order_id}/ship"))        # /app/v1/orders/{order_id}/ship
@router.post(user_api("/{user_id}/activate"))      # /app/v1/users/{user_id}/activate
@router.post(user_api("/{user_id}/reset-password"))# /app/v1/users/{user_id}/reset-password

# 방법 2: PATCH로 상태 필드 변경 (단순 필드 변경)
# PATCH /app/v1/orders/update/{order_id}  {"status": "cancelled"}

# 가이드: 비즈니스 로직이 복잡하면 방법 1, 단순 필드 변경이면 방법 2
```

## Deprecation 처리

```python
@deprecated_version(version=1, sunset_date="2026-06-01", successor_version=2)
async def get_attendance_list(): ...
```

## Idempotency (멱등성)

```python
from core.util.versioning import app

router = APIRouter()
api = app("orders")

# POST 중복 방지: Idempotency-Key 헤더 사용
@router.post(api("/create"), status_code=status.HTTP_201_CREATED)
async def create_order(
    body: CreateOrderRequest,
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
    service: OrderService = Depends(get_order_service),
) -> OrderResponse:
    if idempotency_key:
        existing = await service.find_by_idempotency_key(idempotency_key)
        if existing:
            return existing
    return await service.create_order(body, idempotency_key=idempotency_key)
```

## CI 린트: 하드코딩 경로 금지

```python
# scripts/check_versioning.py
PATTERN = re.compile(r'@router\.(get|post|put|patch|delete)\(\s*["\']/(admin|app|web)/v\d+')
# Fails CI if found → enforce EndpointPath usage
```

## 설계 체크리스트

- [ ] EndpointPath 헬퍼로 경로 생성 (하드코딩 금지)
- [ ] `/{client}/v{version}/{domain}/{action}` 패턴 준수
- [ ] client별 Sub-Application 분리 (admin/app/web)
- [ ] URL은 복수형 명사, kebab-case
- [ ] HTTP 메서드가 의미에 맞음 (GET=조회, POST=생성, ...)
- [ ] 상태 코드가 정확 (201 생성, 204 삭제, 409 충돌, ...)
- [ ] 중첩 리소스 최대 2단계
- [ ] 파라미터 클래스 + Depends() 사용 (핸들러에 Query/Path 직접 나열 금지)
- [ ] 필터/정렬/검색은 Query Parameter
- [ ] PaginatedResponse 사용 (컬렉션)
- [ ] ErrorResponse 형식 통일
- [ ] 비-CRUD 액션에 적절한 패턴 사용
- [ ] Idempotency 고려 (결제 등 중요 POST)
- [ ] JSON 응답은 camelCase (BaseSchema alias)
